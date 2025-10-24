Простенькая программа для поиска дубликатов файлов написанная на языке Swift.

Мне просто хотелось поиграться с:
 - Swift Package Manager;
 - SQLite;
 - Swift for Linux;
 - Swift Testing;
 - а также файловой системой, инлайнами, мутирующими структурами и конкаренси.

```
USAGE: doppelgangers-hunter <path> [--delete] [--skips-hidden-files] [--use-sqlite]

ARGUMENTS:
  <path>                  Путь к каталогу, где надо найти дубликаты

OPTIONS:
  --delete                Автоматически удалять найденные дубликаты
  --skips-hidden-files    Пропускать скрытые файлы
  --use-sqlite            Использовать SQLite базу данных
  -h, --help              Show help information.
```

`swift test`
