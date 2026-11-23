import React from 'react';
import {Composition} from 'remotion';
import {Demo} from './Video';
import {DURATION_FRAMES, FPS, HEIGHT, WIDTH} from './timeline';

export const Root: React.FC = () => (
  <Composition
    id="PlateChaseDemo"
    component={Demo}
    durationInFrames={DURATION_FRAMES}
    fps={FPS}
    width={WIDTH}
    height={HEIGHT}
  />
);
