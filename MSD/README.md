# MSD

Magic Sparkle Donkey is an ECS or entity-component-system architecture for Swift.

## Goals
- As close to optimal memory access as practical
  - ie, components of interest can be laid out contiguously in memory
- Avoid virtual dispatch
- Not coupled to any specific renderer or type of renderer, ie could render with Metal, OpenGL, CoreGraphics, etc
- Experiment with
  - Allow component memory to be stored directly on the GPU, so you can update with a compute function

## Other libraries in Swift
### RealityKit
RealityKit has some nice things built in like PBR shaders, but…
- You can't customize shaders 

### Fireblade-ECS
Using classes ruins the point of the entt-style sparse array representation! Weird.


## Reading
- https://github.com/SanderMertens/ecs-faq
- https://skypjack.github.io/2019-02-14-ecs-baf-part-1/
- https://skypjack.github.io/2019-03-07-ecs-baf-part-2/
- Entt on godbolt https://godbolt.org/z/zxW73f


## TODO:
- [ ] Provide iterator to scene.forEach() that already knows the dense index, ie doesn't need to do any funny business
