package br.com.cactus.fight.onboarding;

import br.com.cactus.fight.audit.AuditService;
import br.com.cactus.fight.security.MfaService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import javax.imageio.ImageIO;
import javax.imageio.stream.MemoryCacheImageInputStream;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
public class OnboardingService {
  private static final ZoneId ACADEMY_ZONE = ZoneId.of("America/Fortaleza");
  private final SecureRandom random = new SecureRandom();
  private final JdbcTemplate jdbc;
  private final PasswordEncoder passwords;
  private final ObjectMapper json;
  private final MfaService secrets;
  private final AuditService audit;

  OnboardingService(JdbcTemplate jdbc, PasswordEncoder passwords, ObjectMapper json, MfaService secrets, AuditService audit) {
    this.jdbc = jdbc;
    this.passwords = passwords;
    this.json = json;
    this.secrets = secrets;
    this.audit = audit;
  }

  record Receipt(UUID registrationId, String academySlug, String academyName, String email, int amountCents,
                 LocalDate firstDueDate, String billingStatus, boolean emailVerified) {}
  record Registration(Receipt receipt, String code, boolean sendEmail) {}

  @Transactional(rollbackFor = Exception.class)
  public Registration register(OnboardingController.Register input) throws Exception {
    UUID id = input.registrationId();
    // Serialize retries before inserting the academy, owner and registration together.
    jdbc.query("select pg_advisory_xact_lock(hashtextextended(?, 0))", rs -> {}, id.toString());
    var existing = lookup(id);
    if (existing != null) {
      String email = input.email().strip().toLowerCase(Locale.ROOT);
      if (!existing.receipt.email.equals(email)) {
        throw failure(HttpStatus.CONFLICT, "registration_conflict");
      }
      // A retry must not silently apply edits to an already saved registration.
      return new Registration(existing.receipt, null, false);
    }

    String document = BrazilianDocument.normalize(input.document());
    if (!BrazilianDocument.valid(input.documentType(), document)) {
      throw failure(HttpStatus.BAD_REQUEST, "invalid_document");
    }
    String phone = input.phone().replaceAll("\\D", "");
    if (!phone.matches("[1-9][0-9]{9,10}")) throw failure(HttpStatus.BAD_REQUEST, "invalid_phone");
    if (input.password().getBytes(StandardCharsets.UTF_8).length > 72) {
      throw failure(HttpStatus.BAD_REQUEST, "password_too_long");
    }
    LocalDate today = LocalDate.now(ACADEMY_ZONE);
    if (input.firstDueDate().isBefore(today) || input.firstDueDate().isAfter(today.plusDays(30))) {
      throw failure(HttpStatus.BAD_REQUEST, "invalid_due_date");
    }

    String email = input.email().strip().toLowerCase(Locale.ROOT);
    String academyName = input.academyName().strip();
    UUID academyId = UUID.randomUUID();
    UUID ownerId = UUID.randomUUID();
    String slug = slug(academyName, academyId);
    int amount = "YEARLY".equals(input.billingPeriod()) ? 32400 : 3000;
    Map<String,Object> branding = new LinkedHashMap<>();
    branding.put("displayName", input.displayName() == null || input.displayName().isBlank()
        ? academyName : input.displayName().strip());
    branding.put("primaryColor", input.primaryColor().toUpperCase(Locale.ROOT));
    branding.put("welcomeMessage", input.welcomeMessage() == null ? "" : input.welcomeMessage().strip());
    branding.put("modalities", input.modalities().stream().distinct().toList());
    String logo = validateLogo(input.logo());
    if (logo != null) branding.put("logoDataUrl", logo);

    jdbc.update("""
        insert into academies(id,slug,legal_name,trade_name,status,plan_code,branding)
        values (?,?,?,?,'TRIAL','MOBILE',cast(? as jsonb))
        """, academyId, slug, input.legalName().strip(), academyName, json.writeValueAsString(branding));
    jdbc.update("""
        insert into users(id,academy_id,name,email,password_hash,role,active)
        values (?,?,?,?,?,'OWNER',false)
        """, ownerId, academyId, input.ownerName().strip(), email, passwords.encode(input.password()));
    String code = newCode();
    jdbc.update("""
        insert into academy_onboardings(id,academy_id,owner_id,document_type,document_encrypted,contact_phone,
          billing_period,payment_method,first_due_date,amount_cents,code_encrypted,code_expires_at)
        values (?,?,?,?,?,?,?,?,?,?,?,now()+interval '20 minutes')
        """, id, academyId, ownerId, input.documentType(), secrets.encrypt(document), phone,
        input.billingPeriod(), input.paymentMethod(), input.firstDueDate(), amount, secrets.encrypt(code));
    audit.user(academyId, ownerId, "ACADEMY_ONBOARDING_CREATED", "academy", academyId.toString(), Map.of());
    return new Registration(new Receipt(id, slug, academyName, email, amount, input.firstDueDate(),
        "PENDING_PAYMENT", false), code, true);
  }

  @Transactional(rollbackFor = Exception.class)
  public Registration resend(UUID id) throws Exception {
    lock(id);
    var pending = required(id);
    if (pending.receipt.emailVerified) return new Registration(pending.receipt, null, false);
    String code = newCode();
    int updated = jdbc.update("""
        update academy_onboardings set code_expires_at=now()+interval '20 minutes',code_encrypted=?,attempts=0
        where id=? and code_expires_at <= now()+interval '19 minutes'
        """, secrets.encrypt(code), id);
    if (updated == 0) throw failure(HttpStatus.TOO_MANY_REQUESTS, "resend_wait");
    return new Registration(pending.receipt, code, true);
  }

  @Transactional(rollbackFor = Exception.class)
  public Receipt verify(UUID id, String code) throws Exception {
    lock(id);
    var pending = required(id);
    if (pending.receipt.emailVerified) return pending.receipt;
    if (pending.attempts >= 5 || !pending.expiresAt.isAfter(OffsetDateTime.now())) return null;
    boolean matches = MessageDigest.isEqual(secrets.decrypt(pending.encryptedCode).getBytes(StandardCharsets.UTF_8),
        code.getBytes(StandardCharsets.UTF_8));
    if (!matches) {
      jdbc.update("update academy_onboardings set attempts=attempts+1 where id=?", id);
      return null;
    }
    jdbc.update("update users set active=true,updated_at=now() where id=? and academy_id=?",
        pending.ownerId, pending.academyId);
    jdbc.update("update academy_onboardings set verified_at=now(),code_encrypted=null where id=?", id);
    audit.user(pending.academyId, pending.ownerId, "ACADEMY_EMAIL_VERIFIED", "academy", pending.academyId.toString(), Map.of());
    return required(id).receipt;
  }

  private void lock(UUID id) {
    jdbc.query("select id from academy_onboardings where id=? for update", rs -> {}, id);
  }

  private Pending required(UUID id) {
    var pending = lookup(id);
    if (pending == null) throw failure(HttpStatus.NOT_FOUND, "registration_not_found");
    return pending;
  }

  private Pending lookup(UUID id) {
    return jdbc.query("""
        select o.*,a.slug,a.trade_name,u.email
        from academy_onboardings o join academies a on a.id=o.academy_id
        join users u on u.id=o.owner_id and u.academy_id=o.academy_id where o.id=?
        """, (rs, row) -> new Pending(
        new Receipt(id, rs.getString("slug"), rs.getString("trade_name"), rs.getString("email"),
            rs.getInt("amount_cents"), rs.getObject("first_due_date", LocalDate.class),
            rs.getString("billing_status"), rs.getObject("verified_at") != null),
        rs.getObject("academy_id", UUID.class), rs.getObject("owner_id", UUID.class),
        rs.getString("code_encrypted"), rs.getObject("code_expires_at", OffsetDateTime.class),
        rs.getInt("attempts")), id).stream().findFirst().orElse(null);
  }

  private record Pending(Receipt receipt, UUID academyId, UUID ownerId, String encryptedCode,
                         OffsetDateTime expiresAt, int attempts) {
  }

  private String newCode() {
    return String.format(Locale.ROOT, "%08d", random.nextInt(100_000_000));
  }

  private static String slug(String name, UUID id) {
    String plain = Normalizer.normalize(name, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
    String slug = plain.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-").replaceAll("^-|-$", "");
    if (slug.isEmpty()) slug = "academia";
    return slug + "-" + id.toString().substring(0, 12);
  }

  private static String validateLogo(String value) {
    if (value == null || value.isBlank()) return null;
    String[] parts = value.split(",", 2);
    if (parts.length != 2 || !(parts[0].equals("data:image/png;base64") || parts[0].equals("data:image/jpeg;base64"))) {
      throw failure(HttpStatus.BAD_REQUEST, "invalid_logo");
    }
    try {
      byte[] bytes = Base64.getDecoder().decode(parts[1]);
      if (bytes.length > 2 * 1024 * 1024) throw new IllegalArgumentException();
      try (var stream = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
        var readers = ImageIO.getImageReaders(stream);
        if (!readers.hasNext()) throw new IllegalArgumentException();
        var reader = readers.next();
        try {
          reader.setInput(stream);
          String format = parts[0].contains("png") ? "png" : "jpeg";
          if (!format.equalsIgnoreCase(reader.getFormatName()) || reader.getWidth(0) > 2400 || reader.getHeight(0) > 2400) {
            throw new IllegalArgumentException();
          }
          reader.read(0);
        } finally {
          reader.dispose();
        }
      }
      return parts[0] + "," + Base64.getEncoder().encodeToString(bytes);
    } catch (Exception ignored) {
      throw failure(HttpStatus.BAD_REQUEST, "invalid_logo");
    }
  }

  static ResponseStatusException failure(HttpStatus status, String code) {
    return new ResponseStatusException(status, code);
  }
}
