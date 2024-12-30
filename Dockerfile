FROM mcr.microsoft.com/playwright:v1.49.1-noble
RUN ["npm", "--version"]
RUN npm install -g netlify-cli node-jq