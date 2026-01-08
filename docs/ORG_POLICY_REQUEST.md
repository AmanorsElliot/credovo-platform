# Organization Policy Exemption Request

## Request Template

**Subject:** Organization Policy Exemption Request for `credovo-eu-apps-nonprod`

**To:** GCP Organization Admin / Platform Team

**Message:**

Hi [Admin Name],

I need to request an exemption from the `gcp.restrictServiceUsage` organization policy constraint for the project `credovo-eu-apps-nonprod` (Project ID: `credovo-eu-apps-nonprod`, Project Number: `858440156644`).

We're deploying infrastructure for the Credovo platform and need the following GCP services enabled:

1. **Cloud Storage** (`storage.googleapis.com`)
   - Purpose: Data lake buckets for raw data, archives, and regional storage
   - Required for: Storing application data, documents, and analytics data

2. **Secret Manager** (`secretmanager.googleapis.com`)
   - Purpose: Secure storage for API keys, JWT secrets, and configuration
   - Required for: Managing Supabase credentials, Sumsub API keys, Companies House API keys

3. **Pub/Sub** (`pubsub.googleapis.com`)
   - Purpose: Event-driven messaging between microservices
   - Required for: KYC event notifications, application lifecycle events

4. **Cloud Tasks** (`cloudtasks.googleapis.com`)
   - Purpose: Asynchronous task processing
   - Required for: KYC verification queue processing

5. **VPC Access** (`vpcaccess.googleapis.com`)
   - Purpose: Private networking connector for Cloud Run services
   - Required for: Secure communication between services

6. **Artifact Registry** (`artifactregistry.googleapis.com`)
   - Purpose: Docker image repository for containerized services
   - Required for: Storing and deploying microservice container images

**Current Status:**
- ✅ IAM permissions are configured correctly
- ✅ Service accounts created successfully
- ✅ Monitoring and logging resources created
- ❌ Blocked by organization policy on the 6 services above

**Request:**
Please add these services to the allowed list for project `credovo-eu-apps-nonprod` in the `gcp.restrictServiceUsage` constraint.

**Alternative:** If there's a different project without these restrictions that we should use instead, please let me know.

Thanks!

---

## How to Submit the Request

### Option 1: Email
Send the above template to your GCP organization admin or platform team.

### Option 2: Slack/Teams
Post in your platform/infrastructure channel with the request details.

### Option 3: Ticket System
If you use a ticketing system (Jira, ServiceNow, etc.), create a ticket with:
- **Title:** "GCP Org Policy Exemption: credovo-eu-apps-nonprod"
- **Description:** Copy the message above
- **Priority:** High (blocking deployment)
- **Labels:** `gcp`, `infrastructure`, `org-policy`

### Option 4: Direct Contact
If you know who manages GCP organization policies, reach out directly.

---

## What the Admin Needs to Do

The GCP organization admin needs to modify the `gcp.restrictServiceUsage` constraint. Here's what they'll need to do:

### Via GCP Console:
1. Go to **IAM & Admin** → **Organization Policies**
2. Select the organization or folder
3. Find `gcp.restrictServiceUsage` constraint
4. Click **Edit**
5. Add the 6 services to the allowed list for project `credovo-eu-apps-nonprod`

### Via gcloud CLI:
They can use a command like:
```bash
gcloud resource-manager org-policies set-policy \
  --project=credovo-eu-apps-nonprod \
  policy.yaml
```

### Via Terraform:
If they manage org policies with Terraform, they'll need to update the constraint configuration.

---

## After Approval

Once the exemption is granted:

1. **Verify services are enabled:**
   ```bash
   gcloud services list --enabled --project=credovo-eu-apps-nonprod | grep -E "storage|secretmanager|pubsub|cloudtasks|vpcaccess|artifactregistry"
   ```

2. **Re-run Terraform:**
   ```bash
   cd infrastructure/terraform
   terraform plan
   terraform apply
   ```

3. **Verify all resources created:**
   ```bash
   terraform state list
   ```

---

## Questions to Ask

If the admin has questions, here are likely answers:

**Q: Why do you need all these services?**
A: We're building a microservices platform with event-driven architecture. Storage for data lake, Secret Manager for secure credential management, Pub/Sub for events, Cloud Tasks for async processing, VPC Access for private networking, and Artifact Registry for container images.

**Q: Can you use a different project?**
A: Yes, if there's a project without these restrictions, we can deploy there instead. The project needs to be in the `europe-west1` region (Belgium) for EU compliance.

**Q: Is this for production?**
A: This is for the `credovo-eu-apps-nonprod` project, which is a non-production environment. We'll need the same services for production later.

**Q: Can you use alternative services?**
A: We've designed the architecture around these GCP services. Alternatives would require significant re-architecture.

