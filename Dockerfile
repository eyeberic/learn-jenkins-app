FROM mcr.microsoft.com/playwright:v1.49.1-noble
RUN apt update && apt install jq unzip -y
RUN npm install -g serve netlify-cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install