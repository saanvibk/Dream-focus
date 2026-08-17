# DreamFocus

## Flutter Web development over SSH

On the remote laptop, from this project directory, run:

```sh
FLUTTER_COMMAND=/home/sanketh/flutter/bin/flutter ./tool/run_web_dev.sh
```

This starts Flutter Web in debug mode using the `web-server` device at
`0.0.0.0:8080`. Keep this terminal open. Press `r` for hot reload and `R` for
hot restart; press `q` to stop the server.

From the local computer, forward the remote port:

```sh
ssh -N -L 8080:127.0.0.1:8080 user@remote-laptop
```

Replace `user@remote-laptop` with the existing SSH destination. Then open
<http://localhost:8080> in the local browser. Keep the SSH command running
while developing.

## Supabase setup

Apply [`supabase/migrations/202608170001_dreamfocus_auth.sql`](/home/sanketh/dreamFocus/supabase/migrations/202608170001_dreamfocus_auth.sql) in the Supabase SQL Editor for the project URL configured in the app. It creates the profile, wallet, and focus-session tables, signup trigger, RLS policies, and the secure focus-session coin RPC.
