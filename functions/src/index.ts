import { initializeApp } from "firebase-admin/app";

initializeApp();

export { onAlertCreated } from "./notify.js";
export { analyzeMessage } from "./analyze.js";
