package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.repository.FoodCatalogRepository;

/**
 * food_catalog on a real database: the entity matches the table (Hibernate validates it at startup) and V9 adds the
 * 24 Turkish dishes of the photo model without nutrition values. The Food-101 rows need the research CSV load, which
 * the test database does not have.
 */
class FoodCatalogIntegrationTest extends PostgresIntegrationTest {

    @Autowired
    private FoodCatalogRepository foodCatalogRepository;

    @Test
    void v9AddsTheTurkishDishesWithoutNutrition() {
        List<FoodCatalogItem> found = foodCatalogRepository.findByNameIn(List.of("lahmacun", "cig_kofte", "simit",
                "no_such_food"));

        assertThat(found).extracting(FoodCatalogItem::getDisplayName)
                .containsExactlyInAnyOrder("Lahmacun", "Çiğ köfte", "Simit");
        assertThat(found).allSatisfy(item -> {
            assertThat(item.getCarbsGPer100g()).isNull();
            assertThat(item.getDefaultServingG()).isNull();
            assertThat(item.isVerified()).isFalse();
        });
        assertThat(foodCatalogRepository.findByNameIn(List.of("asure", "biber_dolmasi", "borek", "cig_kofte",
                "enginar", "et_sote", "gozleme", "hamsi", "hunkar_begendi", "icli_kofte", "ispanak", "izmir_kofte",
                "karniyarik", "kebap", "kisir", "kuru_fasulye", "lahmacun", "lokum", "manti", "mucver",
                "pirinc_pilavi", "simit", "taze_fasulye", "yaprak_sarma"))).hasSize(24);
    }
}
