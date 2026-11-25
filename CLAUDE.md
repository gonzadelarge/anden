# Andén

Private Flutter Android app (GetX) that shows the next Metrovalencia trains for saved trips.
Since 2.0 all data comes from the own server (anden_server, `/v2/`). Installed on two phones through HomePi.

**Start at [AGENTS.md](AGENTS.md).** It is a routing table, not a manual: find the row for the
task, read only the files it lists, and stop. Reading every doc costs ~10k tokens and is almost
never needed. Skill `/load-project-context` does this for you.

Never launch the emulator; the user tests on Android Studio and on the phones.
