# Whiteout survival Alliance homepage
If you've stumbled upon this random side-project, why are you still here?
If you still decide to look at it then I wish you the best of luck!
A friend of mine and myself decided to make this website while we're still learning various development languages so I can't guarantee the most readable layout.

# Whiteout Survival Project Onboarding

## 💻 REQUIRED SOFTWARE
1. **Windows 10/11** (64-bit)
2. **Docker Desktop**  
   [Download here](https://docs.docker.com/desktop/install/windows-install/)  
   *Must enable WSL 2 backend during install*
3. **VS Code**  
   [Download here](https://code.visualstudio.com/download)  
   *With these extensions:*
   - Docker (Microsoft)
   - ESLint
   - PostgreSQL (cweijan)
4. **Git**  
   [Download here](https://git-scm.com/download/win)

## 🚀 SETUP INSTRUCTIONS
### 1. Clone the repository in visual studio code
> 1. Press the search field at the top and write ">Git: Clone", Press enter for "Clone from Github".
> 2. You'll need both of the following projects. (repeat > 1. until you've cloned both projects)
  2.a https://github.com/frodrikandersson/rfa-frontend
  2.b https://github.com/frodrikandersson/rfa-backend

Congratulations, you've successfully cloned both projects. Now open up the projects in any way you like. I prefer to see both projects in one workspace.

## 🔐 SECURE FILES (GET FROM FREDRIK)
Contact frodrikandersson to receive these files:
- `ca.pem` (SSL certificate)     -- Place in certs folder
- `.env` (Database credentials)  -- Place in root folder (where app.ts is located)
*These files must NEVER be shared or committed to Git*

# OPEN DOCKER
Start your local Docker Desktop program

# OPEN UP A TERMINAL
Right click "rfa-backend" and click "open in integrated terminal"

# Build and start
npm install
docker-compose up -d --build

# Check logs
docker-compose logs -f app

# Stop services
docker-compose down

# Good job! Whenever you come back to the project you'll need to do the below instructions in order to start the project again.

> Enter "npm run dev" to start the backend or frontend locally.
> If you have docker set up you can start the docker connection through docker desktop. Click on "Containers", find "rfa-backend" and press the start button.

When we push this live we'll change some localhost urls to Vercels provided url, or something else.

## PROJECT STRUCTURE
rfa-backend/
├── api/                     # Optional extra APIs
├── certs/                   # SSL certs for DB (e.g., Aiven)
├── public/                  # Static files
│   └── assets/              # Image and file assets
├── src/
│   ├── config/              # App configuration (env, DB, etc.)
│   ├── constants/           # Constants and enums
│   ├── controllers/         # Route logic
│   ├── middleware/          # Express middleware
│   ├── models/              # DB models and interfaces
│   ├── routes/              # Route declarations
│   ├── utilities/           # Helper functions
│   └── server.ts            # Server entry point
├── app.ts                   # Express app setup
├── init.sql                 # SQL script to initialize DB schema
├── Dockerfile               # Backend Dockerfile
├── docker-compose.yml       # Full service setup (backend + db)
├── tsconfig.json            # TypeScript config
└── README.md                # You're here