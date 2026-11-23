package com.diamate.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.diamate.backend.entity.ClinicianProfile;

public interface ClinicianProfileRepository extends JpaRepository<ClinicianProfile, Long> {
}
