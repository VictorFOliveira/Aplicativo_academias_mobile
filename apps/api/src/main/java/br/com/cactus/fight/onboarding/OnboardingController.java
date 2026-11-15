package br.com.cactus.fight.onboarding;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/onboarding")
public class OnboardingController {
  private final OnboardingService service;
  private final ObjectProvider<JavaMailSender> mail;
  private final String from;

  OnboardingController(OnboardingService service, ObjectProvider<JavaMailSender> mail,
                       @Value("${cactus.onboarding.from:}") String from) {
    this.service = service;
    this.mail = mail;
    this.from = from;
  }

  public record Register(
      @NotNull UUID registrationId,
      @NotBlank @Pattern(regexp = "CPF|CNPJ") String documentType,
      @NotBlank @Size(max = 24) String document,
      @NotBlank @Size(max = 100) String legalName,
      @NotBlank @Size(max = 48) String academyName,
      @NotBlank @Size(max = 100) String ownerName,
      @NotBlank @Email @Size(max = 120) String email,
      @NotBlank @Size(max = 20) String phone,
      @NotBlank @Size(min = 10, max = 72) String password,
      @NotBlank @Pattern(regexp = "MONTHLY|YEARLY") String billingPeriod,
      @NotBlank @Pattern(regexp = "PIX|CARD") String paymentMethod,
      @NotNull LocalDate firstDueDate,
      @Size(max = 48) String displayName,
      @NotBlank @Pattern(regexp = "#[a-fA-F0-9]{6}") String primaryColor,
      @Size(max = 72) String welcomeMessage,
      @NotNull @Size(min = 1, max = 3) List<@NotBlank @Pattern(regexp = "JUDO|JIUJITSU|MUAY_THAI") String> modalities,
      @Size(max = 2_796_230) String logo,
      boolean billingAuthorized
  ) {}
  public record Code(@NotBlank @Pattern(regexp = "[0-9]{8}") String code) {}
  public record RegisterResult(OnboardingService.Receipt registration, String emailDelivery) {}

  @PostMapping
  public ResponseEntity<RegisterResult> register(@Valid @RequestBody Register input) throws Exception {
    if (!input.billingAuthorized()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "billing_authorization_required");
    requireSender();
    return ResponseEntity.status(HttpStatus.ACCEPTED).body(deliver(service.register(input)));
  }

  @PostMapping("/{id}/resend")
  public RegisterResult resend(@PathVariable UUID id) throws Exception {
    requireSender();
    return deliver(service.resend(id));
  }

  @PostMapping("/{id}/verify")
  public ResponseEntity<?> verify(@PathVariable UUID id, @Valid @RequestBody Code input) throws Exception {
    var receipt = service.verify(id, input.code());
    return receipt == null
        ? ResponseEntity.badRequest().body(Map.of("error", "invalid_or_expired_code"))
        : ResponseEntity.ok(receipt);
  }

  @ExceptionHandler(ResponseStatusException.class)
  ResponseEntity<Map<String,String>> rejected(ResponseStatusException error) {
    return ResponseEntity.status(error.getStatusCode()).body(Map.of("error", error.getReason()));
  }

  private void requireSender() {
    if (from.isBlank() || mail.getIfAvailable() == null) {
      throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "email_service_unavailable");
    }
  }

  private RegisterResult deliver(OnboardingService.Registration registration) {
    if (!registration.sendEmail()) return new RegisterResult(registration.receipt(), "UNCHANGED");
    var message = new SimpleMailMessage();
    message.setFrom(from);
    message.setTo(registration.receipt().email());
    message.setSubject("Cactus Fight — confirme seu e-mail");
    message.setText("Digite este código no Cactus Fight: " + registration.code() + "\n\nO código expira em 20 minutos.");
    try {
      mail.getObject().send(message);
      return new RegisterResult(registration.receipt(), "SENT");
    } catch (MailException error) {
      return new RegisterResult(registration.receipt(), "FAILED");
    }
  }
}
