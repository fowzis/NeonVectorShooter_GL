# NeonVectorShooter_GL
NeonVectorShooter adapted to MonoGame 3.8 using an OpenGL MonoGame Project Template

Make a Neon Vector Shooter work in MonoGame

Introduction to game development using MonoGame sample program based on the tutorials from Michel Hoffman as provided in the his detailed tutorials "Cross-Platform Vector Shooter: XNA" in the following web site: https://gamedevelopment.tutsplus.com/series/cross-platform-vector-shooter-xna--gamedev-10559

The Bloom Shaders .fx file were adapted to work with monogame using PixelShader ps_4_0_level_9_1

The main changes are basically in the BloomComponent.cs class as well as the BloomCombine.fx The BloomCombine parameters were caches (perfoirmance considerations) and the BaseTexture was sent to the shader as a parameter see the following MonoGame community discussion explaining the fix to the BloomCombine to make it work properly with MonoGame. http://community.monogame.net/t/how-to-achieve-a-bloom-effect-on-2d-textures/2614/7
