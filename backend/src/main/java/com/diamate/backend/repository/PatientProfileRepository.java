package com.diamate.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.diamate.backend.entity.PatientProfile;

public interface PatientProfileRepository extends JpaRepository<PatientProfile, Long> {
}
