import { onRequest } from "firebase-functions/v2/https";

export const health = onRequest((req, res) => {
  res.json({ status: "ok", service: "memory-allocation-survival" });
});
