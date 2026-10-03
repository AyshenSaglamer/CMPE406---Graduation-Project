package com.diamate.backend.api.dto.response;

import java.time.Instant;

// record: classes that only hold data, for concise code
public record HealthResponse(String status, String service, Instant timestamp) {
	
}
/* If we hadn't used a "record"
 * 
 *  public class HealthResponse {
 *  	private final String status;
 * 		private final String service;
 *  	private final Instant timestamp;
 *
 *  	public HealthResponse(String status, String service, Instant timestamp) {
 *      	this.status = status;
 *      	this.service = service;
 *      	this.timestamp = timestamp;
 *  	}
 *
 *  	public String getStatus() { return status; }
 *  	public String getService() { return service; }
 *  	public Instant getTimestamp() { return timestamp; }
 *
 *  	// equals(), hashCode(), toString() should also be handwritten
 *  }
 */