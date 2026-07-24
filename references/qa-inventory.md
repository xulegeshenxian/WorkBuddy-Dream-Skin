# QA inventory

## Static gates

* Parse every PowerShell script with the PowerShell language parser
* Run `node --check scripts/injector.mjs`
* Run `node scripts/injector.mjs --check-payload`
* Parse `assets/theme.json`
* Confirm `VERSION` matches the injected version

## Live gates

* Listener is bound only to a loopback address
* Listener executable path matches the selected `WorkBuddy.exe`
* Target protocol is `vscode-file:` or `file:`
* Target title and root element identify WorkBuddy
* Root theme class, style element and chrome element exist
* Injected version matches `VERSION`
* Background and hero art variables contain live image URLs
* Character decoration layer exists even when the active theme does not define a character image
* Decorative chrome has `pointer-events: none`
* WorkBuddy root is visible
* Document has no horizontal overflow
* Top bar text contrast is at least 4.5 when the top bar exists
* Selected conversation text contrast is at least 4.5 when a selection exists
* Decorative brand, status and coordinate labels are hidden on chat pages
* Hover audit covers conversation cards, the More entry, quick actions and the growth plan entry
* Hover surfaces stay dark and keep a text contrast ratio of at least 4.5
* Visible tooltips and overlay text keep a contrast ratio of at least 4.5
* Composer audit covers model trigger hover, workspace trigger hover, permission trigger hover, model popover open and model item hover
* Hover audit covers show more, collapse and workspace section label states in the conversation sidebar
* Verification checks visible Markdown code blocks, code headers and tables for dark readable surfaces
* Verification checks the task preparation overlay whenever it is visible
* Composer audit requires the hovered model item surface to be visibly rendered, and accepts the legacy model description submenu when that surface still exists
* Scene audit opens Office, Coding and Design, then checks recommendation chips in idle and hover states or validates the themed destination when WorkBuddy routes an action directly
* Page audit covers New Task, History Task, Assistant, Projects, Experts, Skills, Connectors, Automation, User Menu and Settings
* History Task audit opens four existing conversations and requires a visible chat page, at least one visible message, a visible composer and hidden welcome decorations in every sample
* Every History Task sample scrolls to the top and back to the bottom, then repeats contrast, pseudo element and horizontal overflow checks at both positions
* History Task audit reports Markdown, code block, table, artifact and scroll metrics for compatibility tracking
* Page audit includes the main content, conversation sidebar and settings modal
* Every audited page has no large light surface, low contrast leaf text, light pseudo element or horizontal overflow
* Detail audit covers Expert Dialog, Project Dialog, Automation Editor, More Menu and Tencent Docs Authorization
* Detail audit verifies the Tencent Docs authorization root is actually visible before accepting the result
* Settings audit covers Account, System, Agents, Shortcuts, Memory, Models, Assistant, Personalization, Data, Security and Help
* Settings audit permits white only inside QR code images needed for reliable scanning
* Workspace, sidebar, chat and composer selectors are reported for compatibility tracking

## Theme compatibility gates

* Schema version 2 accepts separate background, hero and optional character images
* Schema version 1 maps its single image to both background and hero roles
* Reused source images are encoded once in the injected payload
* Character artwork is hidden outside the welcome page
* Applying a saved preset creates an automatic backup of the previous active theme

## Manual visual pass

Check the login page, workspace empty state, active conversation, long code block, artifact panel, narrow window, maximized window and reduced motion mode. Confirm all controls remain clickable and keyboard focus remains visible.
