package com.diamate.backend.entity;

import java.math.BigDecimal;

import org.hibernate.annotations.Immutable;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Maps food_catalog (read only): the foods the photo model can recognise, with per-100 g nutrition. The Food-101
 * rows come from Database/sql/08_reference_seed.sql (or V10), the 24 Turkish dishes of the model from V9; V12 added
 * protein and fat for all of them and the Turkish dishes' nutrition.
 * The values are ROUGH ESTIMATES unless verified is true: the app shows them as "approximate" and they are never used
 * for insulin dosing.
 */
@Entity
@Immutable
@Table(name = "food_catalog")
public class FoodCatalogItem {

    @Id
    private Long id;

    /** The model's class name, e.g. apple_pie. */
    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "display_name", nullable = false, length = 150)
    private String displayName;

    @Column(name = "kcal_per_100g", precision = 6, scale = 1)
    private BigDecimal kcalPer100g;

    @Column(name = "carbs_g_per_100g", precision = 5, scale = 1)
    private BigDecimal carbsGPer100g;

    @Column(name = "protein_g_per_100g", precision = 5, scale = 1)
    private BigDecimal proteinGPer100g;

    @Column(name = "fat_g_per_100g", precision = 5, scale = 1)
    private BigDecimal fatGPer100g;

    @Column(name = "default_serving_g", precision = 6, scale = 1)
    private BigDecimal defaultServingG;

    @Column(name = "is_verified", nullable = false)
    private boolean verified;

    protected FoodCatalogItem() {
        // required by JPA
    }

    /** For tests: the catalog is filled by SQL, never by the application. */
    public FoodCatalogItem(long id, String name, String displayName, BigDecimal kcalPer100g, BigDecimal carbsGPer100g,
            BigDecimal defaultServingG, boolean verified) {
        this(id, name, displayName, kcalPer100g, carbsGPer100g, null, null, defaultServingG, verified);
    }

    /** For tests, with protein and fat. */
    public FoodCatalogItem(long id, String name, String displayName, BigDecimal kcalPer100g, BigDecimal carbsGPer100g,
            BigDecimal proteinGPer100g, BigDecimal fatGPer100g, BigDecimal defaultServingG, boolean verified) {
        this.proteinGPer100g = proteinGPer100g;
        this.fatGPer100g = fatGPer100g;
        this.id = id;
        this.name = name;
        this.displayName = displayName;
        this.kcalPer100g = kcalPer100g;
        this.carbsGPer100g = carbsGPer100g;
        this.defaultServingG = defaultServingG;
        this.verified = verified;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getDisplayName() {
        return displayName;
    }

    public BigDecimal getKcalPer100g() {
        return kcalPer100g;
    }

    public BigDecimal getCarbsGPer100g() {
        return carbsGPer100g;
    }

    public BigDecimal getProteinGPer100g() {
        return proteinGPer100g;
    }

    public BigDecimal getFatGPer100g() {
        return fatGPer100g;
    }

    public BigDecimal getDefaultServingG() {
        return defaultServingG;
    }

    public boolean isVerified() {
        return verified;
    }
}
