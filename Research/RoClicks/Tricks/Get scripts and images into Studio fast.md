---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/get-code-and-art-into-studio
retrieved: 2026-10-15
---
# Get scripts and images into Studio fast

Push big scripts as a model file instead of pasting source, and bulk-upload images through Studio's own login. The two transfers that waste the most agent time.

When an AI agent builds through a Studio MCP server, most wasted time goes on two transfers: getting long scripts in without them breaking, and getting images uploaded at all.

## Scripts: import a model file, don't paste source

Sending a script's source through a tool call can turn every `\n` inside a string into a real line break, and the script then fails with "Malformed string" on a line that looks fine. The tool still reports success, so the error only shows in the output log.

The fix is to write the script into a small Roblox XML model file on disk and import that. The source goes from disk to Studio without passing through the tool call, so nothing gets mangled, and a 2,000-line script doesn't fill up the agent's context either.

``` text
When you push scripts into Studio, don't send the source through set_script_source. Write each script into a .rbxmx file:

<roblox version="4">
  <Item class="ModuleScript" referent="RBX0">
    <Properties>
      <string name="Name">MyModule</string>
      <ProtectedString name="Source"><![CDATA[ ...the Luau source... ]]></ProtectedString>
    </Properties>
  </Item>
</roblox>

Escape any "]]>" inside the source as "]]]]><![CDATA[>". Import it into ServerStorage as staging, then move or copy it into place in one step. Check the output log for errors after every push.
```

If the MCP server can't import files, a second route works: serve your source folder on `127.0.0.1` and have Studio fetch each file with `HttpService:GetAsync` (the same trick Rojo uses). Turn HTTP requests back off before publishing.

## Images: upload through Studio's login

Most MCP servers can't upload images without an Open Cloud key. The built-in Roblox Studio MCP can, because it uploads through the Studio session you're already logged into. Two catches:

- It only takes web addresses, not file paths. Serve the folder locally first: `python3 -m http.server 8791 --bind 127.0.0.1 --directory out`, then pass `http://127.0.0.1:8791/name.png`.
- Send 10 to 12 images per call. A batch of 64 timed out and dropped every Studio connection.

``` text
Upload every PNG in [folder] to Roblox through the built-in Roblox Studio MCP's upload_image:
1. Serve the folder with python3 -m http.server on a free port bound to 127.0.0.1 (check the port first).
2. Get the studio_id from list_roblox_studios.
3. Upload in batches of 10 to 12, passing http://127.0.0.1:<port>/<file> URLs.
4. Save the returned file to asset id map as JSON next to the images, and use those ids in the UI.
```

More: [[Driving Roblox Studio through MCP|driving Roblox Studio through MCP]].

Previous: [[Check a build with 12 screenshots before showing anyone]] · Next: [[AI 3D models that fit a stud-style game]]
