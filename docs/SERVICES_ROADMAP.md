# Services Integration Roadmap

## Currently Integrated Services

### ✅ Completed
1. **KYC/KYB Service** - Identity and company verification
   - Primary: Shufti Pro (240+ countries, 150+ languages)
   - Fallback: SumSub (200+ countries)
   - Status: ✅ Fully operational

2. **Open Banking Service** - Financial data and income verification
   - Provider: Plaid (US, UK, and other supported countries)
   - Features: Account verification, transactions, income verification
   - Status: ✅ Fully operational

3. **Companies House** - UK company verification
   - Provider: Companies House API (UK only)
   - Status: ✅ Basic integration complete

## Services to Integrate

### High Priority

#### 1. Company Search/Autocomplete Service
**Purpose**: Provide real-time company name autocomplete for application forms

**Recommended APIs**:
- **✅ The Companies API** (Default Provider - Recommended) ✅
  - **Status**: ✅ Active and configured as default
  - Company search with autocomplete
  - UK-focused company database
  - Standalone API
  - Production and sandbox API keys configured
  - Documentation: https://www.thecompaniesapi.com/
  - **Recommendation**: ✅ Use this as the primary provider

- **Companies House API** (UK Only - Already Integrated) ✅
  - UK company search and verification
  - Free tier available
  - Already integrated in connector service
  - Documentation: https://developer.company-information.service.gov.uk/

**Implementation Priority**: High - Needed for better UX in application forms
**Current Status**: ✅ The Companies API implemented and configured as default provider

#### 2. Credit Check Service
**Purpose**: Credit scoring and credit history checks

**Recommended Providers**:
- **Experian API** (UK/EU)
  - Credit reports and scores
  - Identity verification
  - Affordability checks
  - Documentation: https://developer.experian.com/

- **Equifax API** (UK/US)
  - Credit reports
  - Credit scores
  - Documentation: https://developer.equifax.com/

- **TransUnion API** (UK/US)
  - Credit reports
  - Credit scores
  - Documentation: https://developer.transunion.com/

**Implementation Priority**: High - Core requirement for mortgage lending

#### 3. Property Valuation (AVM) Service
**Purpose**: Automated property valuation for mortgage applications

**Recommended Providers**:
- **Zoopla API** (UK)
  - Property valuations
  - Property data
  - Documentation: https://developer.zoopla.co.uk/

- **Rightmove API** (UK)
  - Property valuations
  - Market data
  - Documentation: Contact Rightmove for API access

- **Hometrack API** (UK)
  - Automated valuations
  - Property risk assessment
  - Documentation: https://www.hometrack.com/

**Implementation Priority**: High - Required for property-backed loans

### Medium Priority

#### 4. Affordability Service
**Purpose**: Calculate borrower affordability based on income, expenses, and debts

**Status**: Can be built internally using:
- Plaid transaction data (already integrated)
- Credit check data (when credit service is integrated)
- Custom affordability algorithms

**Implementation Priority**: Medium - Can leverage existing Plaid integration

#### 5. AML & Fraud Detection Service
**Purpose**: Enhanced anti-money laundering and fraud detection

**Recommended Providers**:
- **Shufti Pro AML** (Already integrated)
  - AML screening included in KYC/KYB
  - Watchlist checks
  - Status: ✅ Partially integrated

- **Onfido** (Additional)
  - Document verification
  - Biometric verification
  - Fraud detection
  - Documentation: https://developers.onfido.com/

**Implementation Priority**: Medium - Basic AML already covered by Shufti Pro

#### 6. Payment Processing Service
**Purpose**: Process mortgage payments, fees, and transactions

**Recommended Providers**:
- **Stripe** (Recommended)
  - Payment processing
  - Subscription management
  - International support
  - Documentation: https://stripe.com/docs/api

- **GoCardless** (UK/EU)
  - Direct debit processing
  - Recurring payments
  - Documentation: https://developer.gocardless.com/

**Implementation Priority**: Medium - Needed for production but not MVP

### Lower Priority

#### 7. Legal/Execution Service
**Purpose**: Legal document generation and e-signature

**Recommended Providers**:
- **DocuSign API**
  - E-signatures
  - Document management
  - Documentation: https://developers.docusign.com/

- **HelloSign API** (Dropbox Sign)
  - E-signatures
  - Document templates
  - Documentation: https://developers.hellosign.com/

**Implementation Priority**: Low - Can be added later

## Recommended Integration Order

1. **Company Autocomplete API** (The Companies API) - ✅ Implemented
2. **Credit Check Service** (Experian/Equifax) - Core lending requirement
3. **Property AVM Service** (Zoopla/Hometrack) - Required for property loans
4. **Affordability Service** (Internal) - Leverage existing Plaid data
5. **Payment Processing** (Stripe) - Production requirement
6. **Legal/Execution** (DocuSign) - Nice to have

## Integration Pattern

All new integrations should follow the existing pattern:
1. Create connector adapter in `services/connector-service/src/adapters/`
2. Register in `ConnectorManager`
3. Create dedicated service (if needed) following KYC-KYB/Open Banking pattern
4. Add routes to orchestration service
5. Store credentials in Secret Manager
6. Add Terraform configuration
