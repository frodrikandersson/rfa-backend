FROM node:18-alpine

# Set workdir
WORKDIR /usr/src/app

# Install deps
COPY package*.json ./
RUN npm install

# Copy source
COPY . .

# Build TypeScript
RUN npm run build

# Run app
CMD ["npm", "start"]