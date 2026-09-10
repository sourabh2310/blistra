package com.blistra.diet.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class WaterUnitTest {

    @Test
    void normalizesLegacyVariants() {
        assertThat(WaterUnit.normalize("ml")).isEqualTo("ML");
        assertThat(WaterUnit.normalize("mL")).isEqualTo("ML");
        assertThat(WaterUnit.normalize("ML")).isEqualTo("ML");
        assertThat(WaterUnit.normalize("L")).isEqualTo("L");
        assertThat(WaterUnit.normalize("l")).isEqualTo("L");
        assertThat(WaterUnit.normalize("glass")).isEqualTo("GLASS");
        assertThat(WaterUnit.normalize("glasses")).isEqualTo("GLASS");
        assertThat(WaterUnit.normalize("cup")).isEqualTo("CUP");
        assertThat(WaterUnit.normalize("cups")).isEqualTo("CUP");
        assertThat(WaterUnit.normalize("CUP")).isEqualTo("CUP");
    }

    @Test
    void canonicalSetHasFourUnits() {
        assertThat(WaterUnit.values()).hasSize(4);
        assertThat(WaterUnit.isCanonical("ML")).isTrue();
        assertThat(WaterUnit.isCanonical("ml")).isFalse();
    }
}
