Create a new git branch following these rules:

## Branch Name Generation

### Step 1: Check for existing changes
First, check if there are any uncommitted changes or staged files:
```bash
git status --porcelain
git diff --name-only
```

### Step 2: Generate branch name

**If changes exist:**
- Analyze the changed files and their content
- Generate a descriptive branch name based on what the changes do
- Format: `feature/<short-description>` or `fix/<short-description>`
- Example: `feature/add-user-auth` or `fix/login-validation`

**If NO changes exist:**
- Generate a fun branch name based on famous movies and their lead actors
- Use format: `<movie-reference>-<actor-reference>` (all lowercase, hyphens)
- Prefer movies from 2000 onwards, but classic widely-known films are acceptable
- Keep it SHORT and SIMPLE - max 3-4 words total

**Movie-based name examples:**
- `inception-leo` (Inception, Leonardo DiCaprio)
- `matrix-keanu` (The Matrix, Keanu Reeves)
- `wick-reeves` (John Wick, Keanu Reeves)
- `interstellar-mcconaughey` (Interstellar)
- `joker-phoenix` (Joker, Joaquin Phoenix)
- `django-jamie` (Django Unchained, Jamie Foxx)
- `fury-road-tom` (Mad Max: Fury Road, Tom Hardy)
- `social-network-jesse` (The Social Network)
- `batman-bale` (The Dark Knight, Christian Bale)
- `gladiator-russell` (Gladiator, Russell Crowe)
- `potc-johnny` (Pirates of the Caribbean, Johnny Depp)
- `lotr-viggo` (Lord of the Rings, Viggo Mortensen)
- `forrest-tom` (Forrest Gump - classic, widely known)
- `pulp-travolta` (Pulp Fiction - classic)

### Step 3: Create the branch
```bash
git checkout -b <generated-name>
```

### Important Notes
- Never include special characters except hyphens
- Keep branch names under 30 characters when possible
- Make sure the name is memorable but professional enough for work
- Confirm the branch was created successfully
