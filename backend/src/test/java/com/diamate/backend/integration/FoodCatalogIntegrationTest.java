package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.repository.FoodCatalogRepository;

/**
 * food_catalog on a real database: the entity matches the table (Hibernate validates it at startup), V9 adds the 24
 * Turkish dishes of the photo model without nutrition values and V10 the 101 Food-101 foods with their rough
 * estimates. The test database has no research CSV load (like the Docker stack), so every Food-101 row here comes
 * from V10, not from 08_reference_seed.sql.
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

    @Test
    void v10AddsTheFood101FoodsWithRoughEstimates() {
        assertThat(foodCatalogRepository.count()).isEqualTo(125); // every class of the photo model

        FoodCatalogItem pizza = foodCatalogRepository.findByNameIn(List.of("pizza")).getFirst();
        assertThat(pizza.getDisplayName()).isEqualTo("Pizza");
        assertThat(pizza.getCarbsGPer100g()).isNotNull().isPositive();
        assertThat(pizza.getDefaultServingG()).isNotNull().isPositive();
        assertThat(pizza.getKcalPer100g()).isNotNull().isPositive();
        assertThat(pizza.isVerified()).isFalse();

        assertThat(foodCatalogRepository.findAll())
                .filteredOn(item -> item.getCarbsGPer100g() != null)
                .hasSize(101)
                .noneMatch(FoodCatalogItem::isVerified);
    }
}
