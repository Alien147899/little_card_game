// Card-back dedicated shader
// Goal: keep smooth floating while reducing pixel jitter

extern vec2 textureSize; // Texture size

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Approach 1: Box filter with four samples to reduce single-pixel popping
    vec2 pixelSize = 1.0 / textureSize;
    
    // Sample surrounding 2x2 region and average
    vec4 sample1 = Texel(texture, texture_coords);
    vec4 sample2 = Texel(texture, texture_coords + vec2(pixelSize.x, 0.0));
    vec4 sample3 = Texel(texture, texture_coords + vec2(0.0, pixelSize.y));
    vec4 sample4 = Texel(texture, texture_coords + pixelSize);
    
    vec4 avgColor = (sample1 + sample2 + sample3 + sample4) * 0.25;
    
    return avgColor * color;
}

