package com.diamate.backend.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.diamate.backend.entity.FoodCatalogItem;

public interface FoodCatalogRepository extends JpaRepository<FoodCatalogItem, Long> {

    List<FoodCatalogItem> findByNameIn(Collection<String> names);

    /**
     * Foods whose display name ("Çiğ köfte") or class name ("cig_kofte") contains the text; names that start with it
     * come first. displayText is lower case; nameText is lower case with spaces as underscores ("cig kofte" ->
     * "cig_kofte"). Neither may contain the LIKE wildcards % and _ typed by the user (the service removes them).
     */
    @Query("""
            select f from FoodCatalogItem f
            where lower(f.displayName) like concat('%', :displayText, '%') or f.name like concat('%', :nameText, '%')
            order by case when lower(f.displayName) like concat(:displayText, '%')
                               or f.name like concat(:nameText, '%') then 0 else 1 end,
                     f.displayName
            """)
    List<FoodCatalogItem> search(@Param("displayText") String displayText, @Param("nameText") String nameText,
            Pageable page);
}
