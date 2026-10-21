// Daily reminder — mirrors mobile/lib/services/notification_service.dart. The Android app
// schedules a real daily notification at windowHour(); the web prototype asks for browser
// notification permission so the flow is identical, and shows reminders only while open.
import { windowHour } from "./logic";

export async function requestReminderPermission(): Promise<boolean> {
  if (typeof window === "undefined" || !("Notification" in window)) return false;
  if (Notification.permission === "granted") return true;
  if (Notification.permission === "denied") return false;
  try {
    return (await Notification.requestPermission()) === "granted";
  } catch {
    return false;
  }
}

export const reminderTimeLabel = (window: string) => {
  const h = windowHour(window);
  const hh = h % 12 === 0 ? 12 : h % 12;
  return `${hh}:00 ${h < 12 ? "AM" : "PM"}`;
};
