package br.com.cactus.fight.onboarding;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class BrazilianDocumentTest {
  @Test
  void verifiesCpfAndBothCnpjFormats() {
    assertTrue(BrazilianDocument.valid("CPF", BrazilianDocument.normalize("123.456.789-09")));
    assertTrue(BrazilianDocument.valid("CNPJ", BrazilianDocument.normalize("11.222.333/0001-81")));
    assertTrue(BrazilianDocument.valid("CNPJ", BrazilianDocument.normalize("12.ABC.345/01DE-35")));
    assertFalse(BrazilianDocument.valid("CPF", "00000000000"));
    assertFalse(BrazilianDocument.valid("CNPJ", "11222333000180"));
    assertFalse(BrazilianDocument.valid("CNPJ", "12ABC34501DE39"));
  }
}
