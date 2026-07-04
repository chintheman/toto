import { registerRoot, Composition } from "remotion";
import { TotoVideo } from "./TotoVideo";

export const RemotionRoot = () => {
  return (
    <Composition
      id="TotoExplainer"
      component={TotoVideo}
      durationInFrames={900}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};

registerRoot(RemotionRoot);
