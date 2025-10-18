# OAuth Notes (QuickBooks, Gmail)

We will use a Cloudflare Worker for OAuth flows. Secrets live in Worker Variables (never in client). Redirect URIs look like `https://YOUR-WORKER.workers.dev/qbo/callback` etc. When you are ready, we will ship the Worker and scopes.
