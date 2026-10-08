STABLE v14 - Data: $(date +%F)
Features: login, chat, grup, emoji picker, mention, profile, theme, reactions
Rollback rapid:
  cp stable-v14/api.php html/api.php
  cp stable-v14/index.html html/index.html
  docker compose restart
