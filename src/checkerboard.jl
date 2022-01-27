
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




function drawdots!(img, res, color; size = 5)
    for i in res
        img[i[1]-size:i[1]+size i[2]-size:i[2]+size] .= color
    end
end


function draw_rect(img, dots, color = Gray{N0f8}(1); size = 5)
    for i in dots
        # img[i[1]-5:i[1]+5, i[2]-5:i[2]+5] .= color
        draw!(
            img,
            Polygon(
                RectanglePoints(
                    Point(i[2] - size, i[1] - size),
                    Point(i[2] + size, i[1] + size),
                ),
            ),
            color,
        )
    end
end

"""


"""
function kxkneighboardhood(
    chessboard,
    refined1;
    stdatol = 0.1,
    cortol = 0.6,
    n = 25,
    m = 11,
    k = 13,
)
    reut = zeros(Bool, length(refined1))
    board = Float32.(chessboard)
    for (idx, i) in enumerate(refined1)
        x, y = i[1], i[2]
        std1 = !isapprox(std(p1), std(p2); atol = stdatol)
        std2 = !isapprox(std(p3), std(p4); atol = stdatol)
        # cor1 = 10^((cor(vec(p1), vec(reverse(p2))) / 0.8) -1) > cortol
        # cor2 = 10^((cor(vec(p3), vec(reverse(p4))) / 0.8) -1) > cortol
        # if  std1 || std2 || !cor1 || !cor2
        #     continue
        # end
        imgtest = board[x-n:x+n, y-n:y+n]
        res = cor(vec(imgtest), vec(reverse(imgtest)))
        if std1 || std2 || res < 0.7
            continue
        end
        reut[idx] = true
    end
    refined2 = map((x, y) -> y ? x : nothing, refined1, reut)
    refined3 = filter(x -> x !== nothing, refined2)
end

"""
    nonmaxsuppresion(refined3)

returns checkboard refined points after non maximal suppresion, currently uses mean
"""
function nonmaxsuppresion(refined3)
    checked = Set([])
    final1 = []
    function dista(i, j)
        sqrt((i[1] - j[1])^2 + (i[2] - j[2])^2)
    end
    for (idxi, i) in enumerate(refined3)
        if idxi ∉ checked
            dist = []
            for (idxj, j) in enumerate(refined3)
                if idxj ∉ checked
                    dist1 = dista(i, j)
                    if dist1 < 10
                        push!(dist, idxj)
                    end
                end
            end
            local mat = zeros(1, 2)
            for i in dist
                i = refined3[i]
                mat = vcat([i[1] i[2]], mat)
            end
            res = Int64.(floor.(mean(mat[1:end-1, :]; dims = 1)))
            map(d -> push!(checked, d), dist)
            value = CartesianIndex(res[1], res[2])
            push!(final1, value)
        end
    end
    final1
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
function markcorners(
    img::AbstractArray;
    method = harris,
    crthres = Percentile(99),
    LoGparams = 2.0 .^ [3.0],
    filter = (5, 5),
    returnimg = false,
)
    imagecorners = imcorner(img, crthres; method = harris)
    img_cleaned = dilate(mapwindow(median!, (Gray.(imagecorners)), filter))
    results = blob_LoG(Int64.(img_cleaned), LoGparams)
    if returnimg == true
        resultantimage = zeros(size(img))
        map(x -> resultantimage[x.location] = 1, results)
        return map(x -> x.location, results), Gray.(resultantimage)
    else
        return map(x -> x.location, results)
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
    for (idx, i) in enumerate(imgs)
        a = vcat(i[1, :], i[:, end], reverse(i[end, :]), reverse(i[:, 1]))
        numchange = 0
        for num = 2:length(a)
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
function checkboundaries(checkerboard, cords; pixels = [11, 23, 35])
    currentstate = zeros(Bool, length(cords))
    # assumes that checkboard is gray
    checkerboard = checkerboard .> 0.4
    for n in pixels
        n = Int(floor((n - 1) / 2)) - 1
        res = map(x -> checkerboard[x[1]-n:x[1]+n, x[2]-n:x[2]+n], cords)
        # # res = map(x-> Gray.(x .> meanfinite(x)), corners)
        # res = map(x-> x .> 0.4, corners)
        check = segboundariescheck(res)
        currentstate = map(x -> (x > 0) ? true : false, currentstate .+ check)
    end
    refined = map((x, y) -> y ? x : nothing, cords, currentstate)
    refined1 = filter(x -> x !== nothing, refined)
end

"""

processes the checkerboard
"""
function process_image(chessboard)
    # we need a algorithm to check if there is a checkerboard or not in image
    # still need to study how filters from ImageFiltering.jl can improve results
    imagecorners = imcorner(chessboard, Percentile(99); method = Images.harris)
    # imagecorners = fastcorners(chessboard, 11, 0.20) # still gotta check if this is worth it 
    imagecorners = clearborder(imagecorners, 35) # 35 is the boundary width we change
    results =
        map(x -> imagecorners[x] == true ? x : nothing, CartesianIndices(imagecorners))
    results = filter(x -> x !== nothing, results)
    correlationcheck = kxkneighboardhood(chessboard, results;)
    bounds = checkboundaries(chessboard, correlationcheck; pixels = [11, 23, 35])
    # also we need algorithm for checking if we have a board now, with connected components still
    # also we need algorithm for checking if we have outliers and remove them  if they exist
    finalcorners = nonmaxsuppresion(bounds) # return checkboard points
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
