package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/keyvault/azsecrets"
)

type IdentityConfig struct {
	Name     string
	ClientID string
	Client   *azsecrets.Client
}

func createCredential(authMethod, clientID string) (azcore.TokenCredential, error) {
	switch authMethod {
	case "pod-identity":
		return azidentity.NewManagedIdentityCredential(&azidentity.ManagedIdentityCredentialOptions{
			ID: azidentity.ClientID(clientID),
		})
	case "workload-identity":
		return azidentity.NewWorkloadIdentityCredential(&azidentity.WorkloadIdentityCredentialOptions{
			ClientID: clientID,
		})
	case "identity-binding":
		return azidentity.NewWorkloadIdentityCredential(&azidentity.WorkloadIdentityCredentialOptions{
			ClientID: clientID,
		})
	default:
		return nil, fmt.Errorf("unsupported AUTH_METHOD: %s. Supported values: pod-identity, workload-identity, identity-binding", authMethod)
	}
}

func main() {
	log.Println("Starting Azure Key Vault demo application...")

	// Get authentication method from environment variable
	authMethod := os.Getenv("AUTH_METHOD")
	if authMethod == "" {
		log.Fatal("AUTH_METHOD environment variable is not set. Supported values: pod-identity, workload-identity, identity-binding")
	}

	// Validate AUTH_METHOD
	if authMethod != "pod-identity" && authMethod != "workload-identity" && authMethod != "identity-binding" {
		log.Fatalf("Invalid AUTH_METHOD: %s. Supported values: pod-identity, workload-identity, identity-binding", authMethod)
	}

	// Get Key Vault URL from environment variable
	keyVaultURL := os.Getenv("KEYVAULT_URL")
	if keyVaultURL == "" {
		log.Fatal("KEYVAULT_URL environment variable is not set")
	}

	// Get secret name from environment variable (default to "demo-secret")
	secretName := os.Getenv("SECRET_NAME")
	if secretName == "" {
		secretName = "demo-secret"
	}

	// Get managed identity client IDs from environment variables
	clientID1 := os.Getenv("MANAGED_IDENTITY_1_CLIENT_ID")
	clientID2 := os.Getenv("MANAGED_IDENTITY_2_CLIENT_ID")

	if clientID1 == "" || clientID2 == "" {
		log.Fatal("Both MANAGED_IDENTITY_1_CLIENT_ID and MANAGED_IDENTITY_2_CLIENT_ID environment variables must be set")
	}

	// Check if credentials should be rebuilt every run (default: false)
	rebuildCredentials := os.Getenv("REBUILD_CREDENTIALS") == "true"

	// Set up both identities using the specified authentication method
	var identities []*IdentityConfig

	// If not rebuilding credentials every run, set them up once
	if !rebuildCredentials {
		identities = make([]*IdentityConfig, 0, 2)

		// Setup first identity
		cred1, err := createCredential(authMethod, clientID1)
		if err != nil {
			log.Fatalf("Failed to create identity 1 credential: %v", err)
		}

		client1, err := azsecrets.NewClient(keyVaultURL, cred1, nil)
		if err != nil {
			log.Fatalf("Failed to create Key Vault client for identity 1: %v", err)
		}

		identities = append(identities, &IdentityConfig{
			Name:     "identity-1",
			ClientID: clientID1,
			Client:   client1,
		})

		// Setup second identity
		cred2, err := createCredential(authMethod, clientID2)
		if err != nil {
			log.Fatalf("Failed to create identity 2 credential: %v", err)
		}

		client2, err := azsecrets.NewClient(keyVaultURL, cred2, nil)
		if err != nil {
			log.Fatalf("Failed to create Key Vault client for identity 2: %v", err)
		}

		identities = append(identities, &IdentityConfig{
			Name:     "identity-2",
			ClientID: clientID2,
			Client:   client2,
		})
	}

	log.Printf("Authentication method: %s", authMethod)
	log.Printf("Configured to use Key Vault: %s", keyVaultURL)
	log.Printf("Secret name: %s", secretName)
	log.Printf("Identity 1 Client ID: %s", clientID1)
	log.Printf("Identity 2 Client ID: %s", clientID2)
	log.Printf("Rebuild credentials every run: %t", rebuildCredentials)
	log.Printf("Starting secret retrieval loop (every 30 seconds)...")

	// Main loop - retrieve secrets with both identities every 30 seconds
	for {
		timestamp := time.Now().Format("2006-01-02 15:04:05")
		log.Printf("\n=== Iteration at %s ===", timestamp)

		// If rebuilding credentials every run, create them fresh
		if rebuildCredentials {
			identities = make([]*IdentityConfig, 0, 2)

			// Setup first identity
			cred1, err := createCredential(authMethod, clientID1)
			if err != nil {
				log.Printf("ERROR: Failed to create identity 1 credential: %v", err)
				time.Sleep(30 * time.Second)
				continue
			}

			client1, err := azsecrets.NewClient(keyVaultURL, cred1, nil)
			if err != nil {
				log.Printf("ERROR: Failed to create Key Vault client for identity 1: %v", err)
				time.Sleep(30 * time.Second)
				continue
			}

			identities = append(identities, &IdentityConfig{
				Name:     "identity-1",
				ClientID: clientID1,
				Client:   client1,
			})

			// Setup second identity
			cred2, err := createCredential(authMethod, clientID2)
			if err != nil {
				log.Printf("ERROR: Failed to create identity 2 credential: %v", err)
				time.Sleep(30 * time.Second)
				continue
			}

			client2, err := azsecrets.NewClient(keyVaultURL, cred2, nil)
			if err != nil {
				log.Printf("ERROR: Failed to create Key Vault client for identity 2: %v", err)
				time.Sleep(30 * time.Second)
				continue
			}

			identities = append(identities, &IdentityConfig{
				Name:     "identity-2",
				ClientID: clientID2,
				Client:   client2,
			})

			log.Printf("Rebuilt credentials for iteration")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)

		// Try to get secret with both identities
		for _, identity := range identities {
			secret, err := identity.Client.GetSecret(ctx, secretName, "", nil)
			if err != nil {
				log.Printf("ERROR: Failed to get secret using %s (client ID: %s): %v", 
					identity.Name, identity.ClientID, err)
				continue
			}

			if secret.Value == nil {
				log.Printf("ERROR: Secret value is nil for %s (client ID: %s)", 
					identity.Name, identity.ClientID)
				continue
			}

			log.Printf("[%s] retrieved secret content \"%s\" from akv using mi client id \"%s\"", 
				authMethod, *secret.Value, identity.ClientID)
		}

		cancel()

		// Wait 30 seconds before next iteration
		time.Sleep(30 * time.Second)
	}
}
