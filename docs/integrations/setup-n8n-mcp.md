# n8n MCP Server — OpenCode Connection

## Overview

This guide describes how to connect OpenCode to the n8n MCP server exposed by
the lab n8n instance.

- **n8n URL:** `https://n8n.<domain>`
- **MCP endpoint:** `https://n8n.<domain>/mcp-server/http`
- **OpenCode MCP name:** `n8n-mcp`
- **Authentication:** bearer token from the `N8N_MCP_TOKEN` environment variable

Keep MCP configuration in the user-level OpenCode config, not in this
repository. The token is a local secret and must not be committed.

## Prerequisites

1. The n8n service is running and reachable through Traefik.
2. An n8n workflow exposes an MCP Server Trigger over Streamable HTTP.
3. You have an MCP bearer token for the n8n MCP endpoint.
4. OpenCode is installed on the client machine.

## Configure OpenCode

Edit the user-level OpenCode config:

- Windows: `%USERPROFILE%\.config\opencode\opencode.json`
- Linux/macOS: `~/.config/opencode/opencode.json`

Add the MCP server entry under the top-level `mcp` object:

```json
{
  "mcp": {
    "n8n-mcp": {
      "type": "remote",
      "url": "https://n8n.example.com/mcp-server/http",
      "enabled": true,
      "oauth": false,
      "headers": {
        "Authorization": "Bearer {env:N8N_MCP_TOKEN}"
      }
    }
  }
}
```

Replace `n8n.example.com` with the actual n8n hostname.

## Set the Token

Set `N8N_MCP_TOKEN` in the local shell before starting OpenCode.

PowerShell:

```powershell
$env:N8N_MCP_TOKEN = "<token>"
```

Bash:

```bash
export N8N_MCP_TOKEN="<token>"
```

For persistent local setup, store the variable in your OS user environment or
shell profile. Do not add it to `.env`, `.env.example`, or any committed file.

## Validate the Connection

From any directory, run:

```bash
opencode mcp debug n8n-mcp
```

Expected result when OAuth is disabled intentionally:

```text
MCP server n8n-mcp has OAuth explicitly disabled
Done
```

Then verify that OpenCode can call n8n MCP tools, for example by listing
available workflows or executing a known test workflow.

## Troubleshooting

| Issue | Check |
|-------|-------|
| `N8N_MCP_TOKEN` is missing | Confirm the variable is set in the same shell that starts OpenCode. |
| 401/403 from MCP endpoint | Token is wrong, expired, or not accepted by the n8n MCP workflow. |
| 404 from `/mcp-server/http` | MCP Server Trigger workflow is not active or the path differs. |
| TLS or connection error | Check DNS, Traefik, certificate issuance, and that n8n is reachable over HTTPS. |
| OAuth warning | Expected when `oauth: false` is configured and bearer token auth is used. |

## Security Notes

- Never commit bearer tokens or generated OpenCode configs containing secrets.
- Prefer user-level OpenCode configuration for personal MCP connections.
- Rotate the MCP token if it was exposed in logs, screenshots, or committed files.
- Limit n8n MCP workflows to the minimum tools and permissions required.
