FROM denoland/deno:2.9.8
WORKDIR /app
COPY . .
RUN deno cache main.ts
EXPOSE 8091
CMD ["deno", "run", "--allow-all", "main.ts"]