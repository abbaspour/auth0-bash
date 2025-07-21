# Project Guidelines for Auth0 Bash Scripts

## Project Overview
Auth0 Bash Scripts is a comprehensive collection of Bash scripts designed to interact with Auth0's Management API. 
The project provides command-line tools for managing various Auth0 resources and operations, making it easier for developers and administrators to automate Auth0-related tasks.

## Project Structure
The repository is organized into directories that correspond to Auth0 features and resources:

- **users/**: Scripts for user management (create, update, delete users)
- **clients/**: Scripts for managing Auth0 applications/clients
- **connections/**: Scripts for identity provider connections
- **tickets/**: Scripts for password change and email verification tickets
- **roles/**: Scripts for role-based access control
- **multifactor/**: Scripts for multifactor authentication
- **organizations/**: Scripts for organization management
- **password-reset/**: Scripts for password reset workflows
- **rules/**: Scripts for Auth0 rules management
- **actions/**: Scripts for Auth0 actions management
- **branding/**: Scripts for customizing Auth0 branding
- **saml/**: Scripts for SAML configuration
- **tenant/**: Scripts for tenant settings

Each directory contains scripts that follow a consistent pattern, typically accepting command-line arguments for configuration and using curl to make API requests to Auth0.

## Usage Guidelines
1. Most scripts require an Auth0 Management API access token, which can be provided via:
   - Command-line argument: `-a <token>`
   - Environment variable: `export access_token=<token>`

2. Scripts typically provide detailed usage instructions when run with the `-h` flag.

3. Scripts validate that the access token has the required scopes before making API requests.

4. Common parameters across scripts include:
   - `-e <file>`: Path to .env file for environment variables
   - `-v`: Verbose mode for debugging
   - `-h`: Display help/usage information
   - `-t tenant`: Auth0 tenant in the format of tenant@region
   - `-d domain`: fully qualified Auth0 domain
   

## Testing
The project does not include formal tests. When making changes:
1. Test the modified script manually with appropriate parameters
2. Verify that the script produces the expected output
3. Ensure error handling works correctly for invalid inputs

## Code Style Guidelines
1. Follow the existing pattern for script structure:
   - Start with shebang (`#!/usr/bin/env bash`)
   - Include header with author, date, and license information
   - Set `set -euo pipefail` for error handling
   - Define a usage function
   - Process command-line arguments with getopts
   - Validate required parameters
   - Perform the API request with curl
   - Product portable code that works in Linux and MacOS
   - Use latest features and syntax in Bash5
   - Maintain bash scripting best practices 
   - When a functionality is not available in native Bash, use other portable commands like jq, grep, openssl, sed and awk
   - Try to keep arguments consistent across different scripts

2. Maintain consistent error handling:
   - Check for required parameters
   - Validate access token scopes
   - Provide meaningful error messages

3. Keep scripts focused on a single Auth0 operation

4. Use descriptive variable names and add comments for complex logic

## Contribution Guidelines
When contributing to this project:
1. Make minimal changes to achieve the desired functionality
2. Follow the existing code style and patterns
3. Test your changes thoroughly before submitting
4. Update documentation if adding new features or changing behavior