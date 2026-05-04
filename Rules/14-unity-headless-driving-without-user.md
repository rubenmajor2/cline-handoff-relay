# Driving Unity Without Making Ruben Touch the Editor

## The rule

Ruben does not know Unity, does not want to learn Unity, and will not be expected to manually drag-and-drop in the Hierarchy, hit Play, eyeball Inspector panels, click "Import Sample" in Package Manager, or do any other Editor-GUI work. **Every Unity task he hands you must be driven from the terminal end-to-end.** If you find yourself about to write "open the Editor, click X, drag Y to Z" in your `attempt_completion` summary, stop. There is almost always a scripted path. Use it.

## Why this rule exists

On 2026-04-29, Ruben asked Cline to pick up the XRI 2→3 rig migration on `emt-vr-clean`. The original task framing assumed manual Editor surgery — "expand the XR Origin rig in Hierarchy, replace the 24 distinct missing-component GameObjects, prefab one rig, apply to the other 8 scenes." That would have been hours of unfamiliar Editor clicking, plus three rounds of "now click Play and tell me if it errors." His exact words mid-session: *"I don't know the first thing about Unity, so what do you suggest here?"*

The actual fix was a 30-second `rsync` + a 25-second Unity batchmode run + a 30-second smoke test. Zero Editor clicks. 268 missing components → 0 across all 9 scenes simultaneously. He never had to look at the Hierarchy, the Inspector, the Package Manager, or hit Play.

This rule codifies the pattern so the next agent (or future-me) doesn't default back to "well, you'll have to open the Editor and..."

## The two pillars: batchmode + scripted Editor helpers

Every Unity-touching task should reach for these two tools first:

### 1. Unity batchmode — `unity -batchmode -nographics -quit -projectPath . -executeMethod ClassName.MethodName -logFile -`

Unity ships a CLI that runs the full Editor headless. It can compile, import assets, run any static C# method you write under `Assets/Editor/`, and exit cleanly. From the terminal you can:

- Compile the project and capture every CS error
- Open a scene, walk it programmatically, dump results to a flat file
- Re-import folders (just by adding files under `Assets/`, batchmode picks them up)
- Run a Player build (Quest, AVP, WebGL, standalone)
- Extract serialized data from any asset (.unity, .prefab, .asset are all YAML)

**Path on this Mac:** `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity`

**Wrapper template (use this verbatim, adjust slugs):**

```bash
UNITY=/Applications/Unity/Hub/Editor/6000.4.4f1/Unity.app/Contents/MacOS/Unity
PROJ=/Users/rubenmajor/Documents/Projects/<project-slug>
LOG=/tmp/cline-vr-batch-<task-slug>.log
nohup "$UNITY" -batchmode -nographics -quit \
  -projectPath "$PROJ" \
  -executeMethod ClassName.MethodName \
  -logFile "$LOG" \
  > /tmp/cline-vr-batch-<task-slug>-stdout.log 2>&1 &
PID=$!
# poll the log + ps -p $PID until done; ~25-90s typical
```

`-batchmode` plus `-nographics` skips the GUI; `-quit` exits when the executeMethod returns; `-logFile -` (or to a file) keeps the full log.

### 2. Editor helper scripts at `Assets/Editor/Cli*.cs`

Anything you can do in the Editor's UI can be done programmatically. Drop a static C# class under `Assets/Editor/` named `Cli<Verb>.cs` with a public static `Run()` method. The two we already have on `emt-vr-clean`:

- **`CliSceneAudit.cs`** — opens every `Assets/Scenes/*.unity`, walks GameObject hierarchies, counts null/missing components, writes `Logs/scene_audit.txt`.
- **`CliPlayModeSmoke.cs`** — opens every scene, walks every Component on every GameObject via `SerializedObject`, listens for Debug.LogError + Debug.LogException, writes `Logs/play_smoke.txt` with per-scene error/exception counts.

Together these replace the manual "open the Editor, click around, hit Play, watch for errors" loop with two flat-file outputs Cline can grep.

**The smoke-test pattern is the key insight:** you cannot easily enter Play mode synchronously from a static method (Play mode is an async state machine). But you CAN simulate "scene loaded + every component awakened" by walking every GameObject and forcing a `SerializedObject` round-trip on every Component — that triggers any deserialization path / OnValidate hook that would fire on Play. If the rig migration broke serialization or left dangling `MonoScript` refs, this catches it without needing a graphics device or a real Play-mode tick.

## The mental flowchart for any Unity task

When Ruben hands you a Unity task:

1. **Is the goal "edit a serialized asset" (scene, prefab, .asset)?** → Static GUID/YAML rewrite. `.unity` and `.prefab` files are YAML. Open them with Python, walk MonoBehaviour blocks, rewrite `m_Script.guid`, save. NO Editor needed.
2. **Is the goal "import / configure a package thing"?** → Are the files already on disk in `Library/PackageCache/` or somewhere similar? If yes, `rsync` them into `Assets/` with `.meta` GUIDs preserved. NO Editor click needed.
3. **Is the goal "compile + see errors"?** → batchmode + grep `error CS` from the log.
4. **Is the goal "verify scene works"?** → CliSceneAudit (missing components) + CliPlayModeSmoke (runtime errors). Both write flat files.
5. **Is the goal "build for Quest / AVP / WebGL"?** → batchmode `-buildTarget Android -executeMethod Builder.BuildAndroid`. Write the `Builder.BuildAndroid` static method yourself if it doesn't exist.
6. **Is the goal "make a UI thing happen"?** → almost always means "tweak a serialized field in a .unity or .prefab YAML." Falls back to step 1.
7. **Only if none of the above work** → consider asking Ruben to do a single specific click. Even then: write the Editor script first, see if you can drive it via `EditorApplication.delayCall` or `MenuItem` invoked by name from batchmode.

The goal is: every "manual Editor step" you write in your completion summary should have you ask "could this have been a CliWhatever.cs helper?" first.

## Conventions for Editor helpers

- **Filename:** `Assets/Editor/Cli<Verb>.cs` (e.g. `CliSceneAudit`, `CliPlayModeSmoke`, `CliBuildAndroid`, `CliRemapGuids`).
- **Public static `Run()`** as the executeMethod entry point. No args (Unity batchmode passes args via `Environment.GetCommandLineArgs` if you need them).
- **Always end with `EditorApplication.Exit(0)`** on success and `Exit(N)` on failure, where N != 0. Unity won't quit on its own from a static method.
- **Always write a flat-file output** to `Logs/<helper>.txt` so the result survives the Editor closing. Don't rely on Debug.Log only — those go to the batchmode log, which is noisy.
- **Counter-start, run, counter-end pattern** for anything that listens to `Application.logMessageReceived` so you can attribute errors to the specific scene/asset being processed.
- **Don't try to enter Play mode from a static method.** That's async + has its own state machine. Use the SerializedObject roundtrip pattern from `CliPlayModeSmoke` instead — it triggers deserialization without needing real Play mode.

## Conventions for `attempt_completion` on a Unity task

Whenever you finish a Unity-related task, your completion summary must end with:

- **Scripted verification you ran**, with the actual numerical result (e.g. "scene_audit.txt: TOTAL 0 0", "play_smoke.txt: 0 exceptions across 9 scenes")
- **The path to the helper(s)** used (so the next agent can run them again)
- **The path to the batchmode log** (so the next agent can grep for errors)
- **What Editor knowledge Ruben does NOT need to apply** (be explicit: "you don't need to open the Editor, you don't need to hit Play, the rig is already verified")

If you have a "you'll need to manually..." sentence in your summary, go back and try to script that step too. The bar is high.

## Snapshot + rollback discipline

Before any Unity-mutating operation (rsync into Assets/, GUID rewrite, batchmode that triggers re-import), snapshot the project to `_bak/<project>-bak-YYYYMMDD-HHMMSS-<reason>/`. Use `rsync -a --exclude=Library --exclude=Logs --exclude=Temp --exclude=UserSettings --exclude=obj --exclude=Build`. Each snapshot is ~300 MB for `emt-vr-clean`, cheap, lets you say "if this goes sideways, the rollback is one rsync away." This is already a `.clinerules` Boy Scout rule across all VR work — restating because Unity tasks need it more than most.

## What to do when Unity Editor is already open

The Editor holds an exclusive lock on the project. If you need to run batchmode and the Editor is open:

1. Try `osascript -e 'tell application "Unity" to quit'` first (graceful, lets unsaved settings persist).
2. If that doesn't terminate within 4-5 sec, send `kill -TERM <pid>`.
3. As last resort, `kill -KILL <pid>` (you'll lose any unsaved Editor preferences but the project files on disk are safe).
4. After batchmode finishes, **always relaunch Editor headed** if Ruben had it open — don't leave him with nothing to come back to.

## Examples of "Editor click" that are actually scripts

| Manual Editor step | Scripted equivalent |
|---|---|
| Click "Import Sample" on a UPM package | `rsync -a` the `Library/PackageCache/<pkg>/Samples~/<sample>/` folder into `Assets/Samples/` (preserves GUIDs) |
| Click Play and watch for errors | `CliPlayModeSmoke.Run` → `Logs/play_smoke.txt` |
| Look at "Console" for missing scripts | `CliSceneAudit.Run` → `Logs/scene_audit.txt` |
| Drag a script onto a GameObject | YAML edit the .unity / .prefab — add a `MonoBehaviour` block referencing the script's `.cs.meta` GUID |
| Bake a NavMesh | `UnityEditor.AI.NavMeshBuilder.BuildNavMeshAsync()` from a Cli helper |
| Enable / disable a build define | Edit `ProjectSettings/ProjectSettings.asset` YAML or use `PlayerSettings.SetScriptingDefineSymbolsForGroup` from a Cli helper |
| Switch build target to Android | `EditorUserBuildSettings.SwitchActiveBuildTargetAsync` from a Cli helper |
| Apply prefab override | YAML edit the prefab's m_PrefabInstance modifications block |
| "Click yes on the input system backend prompt" | This one DOES require the headed Editor — but it's a single click and survives the project. Do it once with Ruben's blessing, never again. |

## Edge cases where you MUST use the headed Editor (small list)

- **Unity Hub install / module install (Android Build Support, etc.)** — sudo wall, requires Ruben's keystroke. There's no CLI bypass on macOS without admin.
- **Unity license activation on a fresh install.** Headed once, then never again on this Mac.
- **The "enable new input system backends" prompt** that Unity fires when XRI 3 / new InputSystem is added to a project that doesn't yet have it. Single click, persists in `ProjectSettings.asset::activeInputHandler`.
- **Real-device VR Play-mode** with a Quest plugged in. No batchmode equivalent for "actually grab a tracked controller pose." If Ruben has the Quest, he hits Play, but it's a single keystroke and only when end-to-end runtime verification is requested.

For all four, ask Ruben once with a yes/no, then never bother him again.

## Real-case reference (the case that produced this rule)

- Source incident: 2026-04-29 #vr-q1495-path-d-iterate, `emt-vr-clean`.
- Task framing assumed manual rig surgery on 24 GameObjects across 9 scenes.
- Actual fix: `rsync -a --no-perms --chmod=u+w` of three `Samples~` folders into `Assets/Samples/`, ran `CliSceneAudit.Run` in batchmode, ran `CliPlayModeSmoke.Run` in batchmode. Total wall-clock: ~3 minutes including snapshot. 268 → 0 missing components, 0 XRI exceptions on smoke, zero Editor clicks from Ruben.
- Iteration log: `/Users/rubenmajor/Documents/Projects/emt-vr-clean/.cline_iteration_log.md` Phase 4 entry.

## Last updated

2026-04-29 — initial rule. Source case: XRI rig migration on `emt-vr-clean`. Author: Cline (codified at Ruben's explicit ask: *"Can you put this info MCP somewhere how you bypassed me having to touch unity so that you can do this in the future / cline rules, whatever?"*).
