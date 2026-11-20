# Spec Delta

## ADDED Requirements

### Requirement: Keep-list exact-value exceptions
The keep-list SHALL support explicit exceptions, each naming one registry key and one value name. A Registry tweak that a key pattern would reject SHALL be allowed only when its key and value name exactly match an exception. Exceptions SHALL NOT use wildcards.

#### Scenario: Allowed value inside a protected key
- **WHEN** a tweak targets the code-integrity policy key with the value name listed as an exception
- **THEN** the tweak loads and is applied like any other tweak

#### Scenario: Neighbouring value stays protected
- **WHEN** a tweak targets the same protected key with any other value name
- **THEN** the tweak is rejected with a keep-list reason

#### Scenario: Wildcard exception is refused
- **WHEN** the keep-list file declares an exception whose key or value name contains a wildcard
- **THEN** loading the tweaks fails with a message naming the invalid exception, and nothing is applied

#### Scenario: Exceptions never bypass value-name protection
- **WHEN** an exception names a value that is also on the protected value-name list (such as an exploit-mitigation value)
- **THEN** the tweak is still rejected
