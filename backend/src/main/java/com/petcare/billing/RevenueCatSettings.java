package com.petcare.billing;

import java.util.Set;
import java.util.Arrays;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class RevenueCatSettings {
 public final boolean enabled, sandbox;
 public final String apiKey, webhookAuthorization, entitlement, offering, appId;
 public final Set<String> products;
 public final long storageBytes;
 public RevenueCatSettings(
  @Value("${petcare.billing.enabled:false}") boolean enabled,
  @Value("${petcare.billing.sandbox:false}") boolean sandbox,
  @Value("${petcare.billing.api-key:}") String apiKey,
  @Value("${petcare.billing.webhook-authorization:}") String webhookAuthorization,
  @Value("${petcare.billing.entitlement:family_plus}") String entitlement,
  @Value("${petcare.billing.offering:default}") String offering,
  @Value("${petcare.billing.app-id:}") String appId,
  @Value("${petcare.billing.products:}") String products,
  @Value("${petcare.billing.storage-bytes:1073741824}") long storageBytes,
  @Value("${petcare.benefits.preview-enabled:true}") boolean preview) {
  this.enabled=enabled;this.sandbox=sandbox;this.apiKey=apiKey;this.webhookAuthorization=webhookAuthorization;
  this.entitlement=entitlement;this.offering=offering;this.appId=appId;this.storageBytes=storageBytes;
  this.products=Arrays.stream(products.split(",")).map(String::trim).filter(s->!s.isBlank()).collect(Collectors.toUnmodifiableSet());
  if(enabled && (apiKey.isBlank() || webhookAuthorization.length()<32 || entitlement.isBlank() || offering.isBlank() || appId.isBlank() || this.products.isEmpty() || storageBytes<=0 || preview))
   throw new IllegalArgumentException("RevenueCat requires complete configuration and disabled benefits preview");
 }
}
