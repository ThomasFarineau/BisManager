# Locale Translation Instructions

When editing localized messages for this addon, always treat `Locales/enUS.lua` as the source of truth.

Rules:
- If you add, rename, or remove a key in `Locales/enUS.lua`, apply the same key change to every other locale file in `Locales/`.
- Keep the exact same Lua key names in every locale file.
- Preserve formatting tokens exactly: `%s`, `%d`, `|cff...|r`, `\n`, punctuation used by code, and item/link markup.
- Translate only the human-readable message text. Do not change Lua structure, comments that are used as grouping markers, or locale bootstrap lines such as `local L = select(2, ...).L('frFR')`.
- The goal is to create proper translations for each locale, not to add technical fallbacks.
- Do not solve missing translations by copying `enUS.lua` into other locale files, by adding runtime fallback loops, or by leaving entire locale files in English.
- A locale file must contain real translated strings for that language whenever the task is to translate locales.
- If one or two terms are genuinely ambiguous, keep only those specific values in English temporarily and clearly limit that exception to the smallest possible set of keys.
- Do not leave a new key present only in `enUS.lua`.
- After locale edits, quickly compare `Locales/enUS.lua` against the other locale files and make sure the key set matches.

Workflow:
1. Edit `Locales/enUS.lua` first.
2. Propagate the same keys to `frFR`, `deDE`, `esES`, `esMX`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.
3. Write proper translations in each target language, consistent with the existing tone already used in each file.
4. Do not stop at structural synchronization if the request is about translation quality.
