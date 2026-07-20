import { Composition } from "remotion";
import { TotoVideo } from "./TotoVideo";

export const RemotionRoot = () => {
  return (
    <Composition
      id="TotoExplainer"
      component={TotoVideo}
      durationInFrames={945}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
