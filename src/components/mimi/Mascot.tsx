import brave from "@/assets/mascot/mimi-brave.png";
import cheer from "@/assets/mascot/mimi-cheer.png";
import face from "@/assets/mascot/mimi-face.png";
import heart from "@/assets/mascot/mimi-heart.png";
import listen from "@/assets/mascot/mimi-listen.png";
import read from "@/assets/mascot/mimi-read.png";
import think from "@/assets/mascot/mimi-think.png";
import wave from "@/assets/mascot/mimi-wave.png";
import { cn } from "@/lib/utils";

export const mascots = { wave, cheer, listen, brave, read, heart, think, face } as const;
export type MascotPose = keyof typeof mascots;

export function Mascot({ pose = "wave", className, alt = "" }: { pose?: MascotPose; className?: string; alt?: string }) {
  return <img src={mascots[pose]} alt={alt} width={512} height={512} draggable={false} className={cn("select-none object-contain", className)} />;
}
