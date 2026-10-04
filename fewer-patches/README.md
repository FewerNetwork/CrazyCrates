# CrazyCrates 5.2.0 location loading patch

The five Java source files come from upstream release commit
`197d8409197c8af83619a71f4fc3161f449741ca`. Location storage now uses
`Map<CrazyLocation, CrateStatus>` rather than using the shared status enum as
the map key. `LinkedHashMap` preserves saved file order. All storage consumers
read the new key/value direction. The saved YAML schema and commands are unchanged.

`scripts/build-patch.ps1` compiles only these sources against the existing
5.2.0 distribution and supplied dependencies. Source imports are relocated in
generated build copies to match the distribution. Its optional CMI compile
signature is excluded from the output. The resulting jar preserves every other
entry, updating only the compiled classes and the displayed plugin version.

Dependencies: Java 25, Paper API 26.2, Adventure, annotations, JOML, SLF4J,
Guava/Gson, Mockito 5.15.2, Byte Buddy 1.15.11, and Objenesis. Pass a directory
containing these dependency jars. The original plugin supplies shaded libraries.

```powershell
./scripts/build-patch.ps1 -OriginalJar /path/to/CrazyCrates-5.2.0.jar -DependencyDirectory /path/to/dependencies
```

The regression calls the actual YAML factory, saves a temporary locations file,
reloads it, and checks six valid placements, order, per-ID lookup, multiple
failed/unavailable entries, unloaded-world entries, and immediate removal.
World registration in a running Paper server still requires deployment testing.
