
"""
    function innercorners(length::Int, width::Int)
    
return innercorners in a checkerboard of size length * width
"""
function innercorners(length::Int, width::Int)
    (length - 1) * (width - 1) 
end

"""
    allboardcorners(length::Int, width::Int)

returns allboardcorners in a checkerboard of size length * width






"""
function allcorners(length::Int, width::Int)
    (length + 1) * (width + 1)
end

"""
    markcorners(img::AbstractArray; method = harris, crthres = Percentile(99), LoGparams = 2.0.^[3.0], filter = (5,5), returnimg = true)

returns corners of checkerboard in an image with size length * width

### Arguments
- `img`: image to be processed
- `method`: method to be used for corner detection
- `crthres`: threshold for corner imcorner method
- `LoGparams`: parameters for LoG filter
- `filter`: size of filter for mapwindow
- `returnimg`: if true, returns image with corners marked

### Example
```jl

using CameraCalibrations
```
"""
function markcorners(img::AbstractArray; method = harris, crthres = Percentile(99), LoGparams = 2.0.^[3.0], filter = (5,5), returnimg = false)
    imagecorners = imcorner(img, crthres; method= harris);
    img_cleaned = dilate( mapwindow( median!, (Gray.(imagecorners)), filter))
    results = blob_LoG( Int64.(img_cleaned), LoGparams)
    if returnimg == true
        resultantimage = zeros(size(img))
        map(x->resultantimage[x.location] = 1, results)
        return map(x->x.location, results), Gray.(resultantimage)
    else
        return  map(x->x.location, results)
    end
end

"""
    segboundariescheck(imgs; numcheck = 4)

returns if the boundaries of the images has different segments to detect different segments:

### Arguments

- `imgs`: images to be processed
- `numcheck`: number of segments in boundary to be detected

Retuns a bool array for of the images and if they satisfy the condition, we return true else false
### Example

We have a corner that looks something like below:

000111
000111
111000
111000

We want to check if the boundary is made up of 4 segments.
Boundary in this case would be : 000111100001111 starting from top edges and going clockwise.
In this we can say we have 4 changes in the boundary.
Numcheck is the number of changes we want to check.

"""
function segboundariescheck(imgs; numcheck = 4)
    check = zeros(Bool, length(imgs))
    for (idx,i) in enumerate(imgs)
        a = vcat(i[1,:],i[:,end], reverse(i[end,:]), reverse(i[:,1]))
        numchange = 0
        for num in 2:length(a)
            if a[num] == 1 && a[num-1] == 0 || a[num] == 0 && a[num-1] == 1
                numchange = numchange + 1
            end
        end
        if numchange == numcheck
            check[idx] = true
        end
    end
    check
end

"""
    checkboundaries(checkerboard, cords; pixels = [11,23,35])

returns true if boundaries satisfy segboundariescheck for a range of pixels regions

### Arguments
- 'checkerboard': checkerboard img to be processed
- 'cords' : array of cartesian indices which indicaes corners in a image
- `pixels`: array of pixels region to be checked centered at cords
"""
function checkboundaries(checkerboard, cords; pixels = [11,23,35])
    currentstate = zeros(Bool, length(cords))
    for n in pixels
        n = Int((n-1)/2) - 1
        corners = map(x->Gray.(checkerboard[x[1]-n:x[1]+n,x[2]-n:x[2]+n]), cords)
        res = map(x-> Gray.(x .> meanfinite(x)), corners)
        check = segboundariescheck(res)
        currentstate = map(x -> (x > 0) ? true : false, currentstate .+ check)
    end
    currentstate
end

"""
    videotrack()

To work with realtime data after corners have been detected, use videotrack.
"""
# function videotrack()
#     if :GLMakie ∉ names(Main,imported=true)
#         throw(error("GLMakie needs to be imported first"))
#     end
#     try 
        
#         img = read(cam)
#         fig = GLMakie.Figure(size = (1000, 700), title = "Checkerboard detection")
#         ax = GLMakie.Axis(
#             fig[1, 1],
#             aspect = DataAspect(),
#             xlabel = "x",
#             xlabelcolor = :black,
#             ylabel = "y label",
#             ylabelcolor = :white,
#             title = "Image",
#             backgroundcolor = :black,
#             labelcolor = :white,
#         )
#         node = Node(rotr90(img))
#         makieimg = image!(ax, node)
#         while isopen(cam)
#             read!(cam, img)
#             res, img = markcorners(img; returnimg = true)
#             node[] = rotr90(img)
#             if ispressed(scene, Keyboard.q) == true
#                 close(cam)
#                 return
#             end 
#             sleep(1 / VideoIO.framerate(cam))
#         end
#         close(cam)
#     catch e
#         try  
#             close(cam)
#         catch e
#             throw(error("Could not close camera camera"))
#         end
#         throw(error("Unable to open webcam"))
#     end
# end
