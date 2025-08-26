
# Dev stage
FROM node:current-alpine3.22 AS dev

WORKDIR /app


COPY package*.json ./
RUN npm install


COPY . .


EXPOSE 3000 9229


CMD ["npm", "run", "dev"]


# Prod stage

FROM node:current-alpine3.22 AS prod

WORKDIR /app

COPY package*.json ./
RUN npm install --only=production

COPY . .

EXPOSE 3000

CMD ["node", "src/index.js"]