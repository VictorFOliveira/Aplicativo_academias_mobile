package br.com.cactus.fight.onboarding;

import java.util.Locale;

final class BrazilianDocument {
  private static final int[] CNPJ_FIRST = {5,4,3,2,9,8,7,6,5,4,3,2};
  private static final int[] CNPJ_SECOND = {6,5,4,3,2,9,8,7,6,5,4,3,2};

  static String normalize(String input) {
    return input.toUpperCase(Locale.ROOT).replaceAll("[./\\s-]", "");
  }

  static boolean valid(String type, String value) {
    if ("CPF".equals(type)) {
      if (!value.matches("[0-9]{11}") || value.chars().distinct().count() == 1) return false;
      return cpfDigit(value, 9) == value.charAt(9) - '0'
          && cpfDigit(value, 10) == value.charAt(10) - '0';
    }
    if (!"CNPJ".equals(type) || !value.matches("[0-9A-Z]{12}[0-9]{2}")
        || value.chars().distinct().count() == 1) return false;
    return cnpjDigit(value, CNPJ_FIRST) == value.charAt(12) - '0'
        && cnpjDigit(value, CNPJ_SECOND) == value.charAt(13) - '0';
  }

  private static int cpfDigit(String value, int length) {
    int sum = 0;
    for (int i = 0; i < length; i++) sum += (value.charAt(i) - '0') * (length + 1 - i);
    int remainder = sum * 10 % 11;
    return remainder == 10 ? 0 : remainder;
  }

  private static int cnpjDigit(String value, int[] weights) {
    int sum = 0;
    for (int i = 0; i < weights.length; i++) sum += (value.charAt(i) - '0') * weights[i];
    int remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  private BrazilianDocument() {}
}
