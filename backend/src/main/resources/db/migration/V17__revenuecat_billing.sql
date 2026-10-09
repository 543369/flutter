-- Preserve purchase ownership when accounts/households are removed. No cascade.
-- RevenueCat is the transaction source of truth; this table is an entitlement cache.
CREATE TABLE revenuecat_customers (
 account_id CHAR(36) PRIMARY KEY,
 app_user_id CHAR(36) NOT NULL UNIQUE,
 household_id CHAR(36) NOT NULL,
 active_until TIMESTAMP(6) NULL,
 verified_at TIMESTAMP(6) NULL,
 checked_at TIMESTAMP(6) NULL,
 INDEX rc_household (household_id),
 INDEX rc_check (checked_at)
);
