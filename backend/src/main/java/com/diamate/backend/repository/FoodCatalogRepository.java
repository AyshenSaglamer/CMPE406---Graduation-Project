package com.diamate.backend.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.diamate.backend.entity.FoodCatalogItem;

public interface FoodCatalogRepository extends JpaRepository<FoodCatalogItem, Long> {

    List<FoodCatalogItem> findByNameIn(Collection<String> names);
}
