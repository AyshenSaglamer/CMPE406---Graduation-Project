package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;

import com.diamate.backend.entity.FoodCatalogItem;
import com.diamate.backend.repository.FoodCatalogRepository;

/**
 * food_catalog on a real database: the entity matches the table (Hibernate validates it at startup), V9 adds the 24
 * Turkish dishes of the photo model, V10 the 101 Food-101 foods with their rough estimates and V12 protein, fat and
 * the Turkish dishes' nutrition. The test database has no research CSV load (like the Docker stack), so every
 * Food-101 row here comes from V10, not from 08_reference_seed.sql.
 */
class FoodCatalogIntegrationTest extends PostgresIntegrationTest {

    @Autowired
    private FoodCatalogRepository foodCatalogRepository;

    @Test
    void v9AddsTheTurkishDishesAndV12TheirRoughNutrition() {
        List<FoodCatalogItem> found = foodCatalogRepository.findByNameIn(List.of("lahmacun", "cig_kofte", "simit",
                "no_such_food"));

        assertThat(found).extracting(FoodCatalogItem::getDisplayName)
                .containsExactlyInAnyOrder("Lahmacun", "Çiğ köfte", "Simit");
        assertThat(foodCatalogRepository.findByNameIn(List.of("asure", "biber_dolmasi", "borek", "cig_kofte",
                "enginar", "et_sote", "gozleme", "hamsi", "hunkar_begendi", "icli_kofte", "ispanak", "izmir_kofte",
                "karniyarik", "kebap", "kisir", "kuru_fasulye", "lahmacun", "lokum", "manti", "mucver",
                "pirinc_pilavi", "simit", "taze_fasulye", "yaprak_sarma")))
                .hasSize(24)
                .allSatisfy(item -> {
                    assertThat(item.getCarbsGPer100g()).isNotNull();
                    assertThat(item.getKcalPer100g()).isNotNull().isPositive();
                    assertThat(item.getDefaultServingG()).isNotNull().isPositive();
                    assertThat(item.isVerified()).isFalse(); // rough estimates, never for dosing
                });
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
    }

    @Test
    void v12GivesEveryFoodAllFourValuesThatAgreeWithItsEnergy() {
        assertThat(foodCatalogRepository.findAll()).hasSize(125).allSatisfy(item -> {
            assertThat(item.getProteinGPer100g()).as(item.getName()).isNotNull();
            assertThat(item.getFatGPer100g()).as(item.getName()).isNotNull();
            assertThat(item.getCarbsGPer100g()).as(item.getName()).isNotNull();
            // 4 kcal per g of carbs and protein, 9 per g of fat: within 10 kcal of the stated energy (rounding, and
            // lokum, whose sugar alone is about its energy).
            BigDecimal energy = item.getCarbsGPer100g().add(item.getProteinGPer100g()).multiply(BigDecimal.valueOf(4))
                    .add(item.getFatGPer100g().multiply(BigDecimal.valueOf(9)));
            assertThat(energy.subtract(item.getKcalPer100g()).abs()).as(item.getName())
                    .isLessThanOrEqualTo(BigDecimal.TEN);
        });
    }

    @Test
    void searchFindsByDisplayNameOrClassNameStartsFirst() {
        assertThat(foodCatalogRepository.search("çiğ", "çiğ", PageRequest.of(0, 20)))
                .extracting(FoodCatalogItem::getName).containsExactly("cig_kofte");
        assertThat(foodCatalogRepository.search("cig kofte", "cig_kofte", PageRequest.of(0, 20)))
                .extracting(FoodCatalogItem::getName).containsExactly("cig_kofte");
        // "Pizza" starts with "piz"; nothing else contains it.
        assertThat(foodCatalogRepository.search("piz", "piz", PageRequest.of(0, 20)))
                .extracting(FoodCatalogItem::getName).first().isEqualTo("pizza");
        // Starts-with first: "Kebap" before foods that only contain "keb".
        assertThat(foodCatalogRepository.search("ke", "ke", PageRequest.of(0, 3)).getFirst().getDisplayName())
                .startsWith("Ke");
    }
}
