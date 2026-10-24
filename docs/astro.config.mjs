import { defineConfig } from "astro/config";

export default defineConfig({
  output: "static",
  build: {
    format: "file"
  },
  markdown: {
    shikiConfig: {
      theme: "github-dark-default",
      wrap: true
    }
  }
});
