
class Ruse
  
  
  _loadShader: (gl, source, type) ->
    
    shader = gl.createShader(type)
    gl.shaderSource(shader, source)
    gl.compileShader(shader)
    
    compiled = gl.getShaderParameter(shader, gl.COMPILE_STATUS)
    unless compiled
      gl.deleteShader(shader)
      return null
    
    return shader
  
  _createProgram: (gl, vertexShader, fragmentShader) ->
    vertexShader = @_loadShader(gl, vertexShader, gl.VERTEX_SHADER)
    fragmentShader = @_loadShader(gl, fragmentShader, gl.FRAGMENT_SHADER)
    
    program = gl.createProgram()
    
    gl.attachShader(program, vertexShader)
    gl.attachShader(program, fragmentShader)
    gl.linkProgram(program)
    
    linked = gl.getProgramParameter(program, gl.LINK_STATUS)
    unless linked
      gl.deleteProgram(program)
      return null
      
    gl.useProgram(program)
    
    program.aVertexPosition1 = gl.getAttribLocation(program, "aVertexPosition1")
    gl.enableVertexAttribArray(program.aVertexPosition1)
    
    program.aVertexPosition2 = gl.getAttribLocation(program, "aVertexPosition2")
    gl.enableVertexAttribArray(program.aVertexPosition2)
    
    program.uPMatrix = gl.getUniformLocation(program, "uPMatrix")
    program.uMVMatrix = gl.getUniformLocation(program, "uMVMatrix")
    
    return program
    
  _createProgramAxes: (gl, vertexShader, fragmentShader) ->
    vertexShader = @_loadShader(gl, vertexShader, gl.VERTEX_SHADER)
    fragmentShader = @_loadShader(gl, fragmentShader, gl.FRAGMENT_SHADER)
    
    program = gl.createProgram()
    
    gl.attachShader(program, vertexShader)
    gl.attachShader(program, fragmentShader)
    gl.linkProgram(program)
    
    linked = gl.getProgramParameter(program, gl.LINK_STATUS)
    unless linked
      gl.deleteProgram(program)
      return null
      
    gl.useProgram(program)
    
    program.aVertexPosition = gl.getAttribLocation(program, "aVertexPosition")
    gl.enableVertexAttribArray(program.aVertexPosition)
    
    program.uPMatrix = gl.getUniformLocation(program, "uPMatrix")
    program.uMVMatrix = gl.getUniformLocation(program, "uMVMatrix")
    
    return program
  
  _setMatrices: (program) ->
    @gl.useProgram(program)
    @gl.uniformMatrix4fv(program.uPMatrix, false, @pMatrix)
    @gl.uniformMatrix4fv(program.uMVMatrix, false, @mvMatrix)
  
  _toRadians: (deg) ->
    return deg * 0.017453292519943295
  
  _setupMouseControls: ->
    
    @drag = false
    @xOldOffset = null
    @yOldOffset = null
    @xOffset = 0
    @yOffset = 0
    
    @axesCanvas.onmousedown = (e) =>
      @drag = true
      @xOldOffset = e.clientX
      @yOldOffset = e.clientY
      
    @axesCanvas.onmouseup = (e) =>
      @drag = false
      
    @axesCanvas.onmousemove = (e) =>
      return unless @drag
      
      x = e.clientX
      y = e.clientY
      
      deltaX = x - @xOldOffset
      deltaY = y - @yOldOffset
      
      rotationMatrix = mat4.create()
      mat4.identity(rotationMatrix)
      mat4.rotateY(rotationMatrix, rotationMatrix, @_toRadians(deltaX / 4))
      mat4.rotateX(rotationMatrix, rotationMatrix, @_toRadians(deltaY / 4))
      mat4.multiply(@rotationMatrix, rotationMatrix, @rotationMatrix)
      
      @xOldOffset = x
      @yOldOffset = y
      
      @draw()
      @drawAxes3d()
      
      # NOTE: Code below is for panning in 2D frame.
      
      # deltaX = x - @xOldOffset
      # deltaY = y - @yOldOffset
      # 
      # deltaXP = @x2xp(deltaX)
      # deltaYP = @y2yp(deltaY)
      # 
      # delta = [deltaXP, deltaYP, 0.0]
      # mat4.translate(@mvMatrix, @mvMatrix, delta)
      # 
      # @xOldOffset = x
      # @yOldOffset = y
      # 
      # @draw()
      # 
      # # Update axes too!
      # @xOffset += deltaX
      # @yOffset += deltaY
      # @drawAxes()
    
    @axesCanvas.onmouseout = (e) =>
      @drag = false
    
    @axesCanvas.onmouseover = (e) =>
      @drag = false
  
  
  constructor: (arg, width, height) ->
    
    # Plot style parameters
    @margin = 0.02  # percentage
    @fontSize = 10
    @tickFontSize = 9
    @fontFamily = "Helvetica"
    @axisPadding = 4
    @xTicks = 6
    @yTicks = 6
    @xTickSize = 4
    @yTickSize = 4
    @tickDecimals = 3
    
    # Plot parameters
    @targetBinWidth = 1  # pixel units
    @bins = null
    @drawMode = null
    @extents = null
    @hasData = false
    
    # Either initialize a WebGL context or utilize an existing one
    s = arg.constructor.toString()
    if s.indexOf('WebGLRenderingContext') > -1 or s.indexOf('rawgl') > -1
      @gl = arg
      @canvas = arg.canvas
      @width = @canvas.width
      @height = @canvas.height
      @canvas.style.position = 'absolute'
    else
      # Assume we have a DOM element and width and height have been provided
      @width = width
      @height = height
      
      # Create and attach canvas to DOM
      @canvas = document.createElement('canvas')
      @canvas.setAttribute('width', @width)
      @canvas.setAttribute('height', @height)
      @canvas.setAttribute('class', 'ruse')
      @canvas.style.position = 'absolute'
      
      @gl = @canvas.getContext('webgl') or @canvas.getContext('experimental-webgl')
      return null unless @gl
      
      arg.appendChild(@canvas)
    
    # Initialize a secondary canvas for axes and ticks
    @axesCanvas = document.createElement('canvas')
    @axesCanvas.setAttribute('width', @width)
    @axesCanvas.setAttribute('height', @height)
    @axesCanvas.setAttribute('class', 'ruse axes')
    @axesCanvas.style.position = 'absolute'
    @gl.canvas.parentElement.appendChild(@axesCanvas)
    
    # Initialize programs from shaders
    shaders = @constructor.Shaders
    @programs = {}
    @programs["ruse"] = @_createProgram(@gl, shaders.vertex, shaders.fragment)
    @programs["axes"] = @_createProgram(@gl, shaders.axesVertex, shaders.axesFragment)
    
    # Get uniforms
    @uMinimum1 = @gl.getUniformLocation(@programs.ruse, "uMinimum1")
    @uMaximum1 = @gl.getUniformLocation(@programs.ruse, "uMaximum1")
    @uMinimum2 = @gl.getUniformLocation(@programs.ruse, "uMinimum2")
    @uMaximum2 = @gl.getUniformLocation(@programs.ruse, "uMaximum2")
    @uZComponent = @gl.getUniformLocation(@programs.ruse, "uZComponent")
    @uTime = @gl.getUniformLocation(@programs.ruse, "uTime")
    @uMargin = @gl.getUniformLocation(@programs.ruse, "uMargin")
    
    # Set initial values for uniforms
    @gl.useProgram(@programs.ruse)
    @gl.uniform1f( @uMargin, @getMargin() )
    
    # Set up camera parameters
    @pMatrix = mat4.create()
    @mvMatrix = mat4.create()
    @rotationMatrix = mat4.create()
    @_setMatrices(@programs.ruse)
    
    @gl.viewport(0, 0, @width, @height)
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)
    @gl.enable(@gl.DEPTH_TEST)
    
    # Create buffers to store data
    @dataBuffer1 = @gl.createBuffer()
    @dataBuffer2 = @gl.createBuffer()
    
    # Create buffer for 3D axes
    @axesBuffer = @gl.createBuffer()
    @axesBuffer2 = @gl.createBuffer()
    
    # Set parameters that store state
    @switch = 0
    @state = null
    @isAnimating = false
    
    @setupAxes3d()
    
  #
  # Draw functions
  #
  
  draw: ->
    @gl.useProgram(@programs.ruse)
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)
    
    # TODO: Might be good to move this outside of draw
    #       so that matrices are not computed twice (plot and axes)
    mat4.identity(@mvMatrix)
    mat4.translate(@mvMatrix, @mvMatrix, @translateBy)
    mat4.multiply(@mvMatrix, @mvMatrix, @rotationMatrix)
    
    @_setMatrices(@programs.ruse)
    
    # Bind buffer for draw
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @dataBuffer1)
    @gl.vertexAttribPointer(@programs.ruse.aVertexPosition1, @dataBuffer1.itemSize, @gl.FLOAT, false, 0, 0)
    @gl.drawArrays(@drawMode, 0, @dataBuffer1.numItems)
  
  removeAxes: ->
    @axesCanvas.width = @axesCanvas.width
  
  setupAxes3d: ->
    lineWidth = 0.01
    vertices = new Float32Array([
      
      # X axis
      -1.0, -lineWidth, 0.0,
      1.0, -lineWidth, 0.0,
      -1.0, lineWidth, 0.0,
      
      -1.0, lineWidth, 0.0,
      1.0, lineWidth, 0.0,
      1.0, -lineWidth, 0.0
      
      # Y axis
      -lineWidth, -1.0, 0.0,
      -lineWidth, 1.0, 0.0,
      lineWidth, -1.0, 0.0,
      
      lineWidth, -1.0, 0.0,
      lineWidth, 1.0, 0.0,
      -lineWidth, 1.0, 0.0,
      
      # Z axis
      -lineWidth, 0.0, -1.0,
      -lineWidth, 0.0, 1.0,
      lineWidth, 0.0, -1.0,
      
      lineWidth, 0.0, -1.0,
      lineWidth, 0.0, 1.0,
      -lineWidth, 0.0, 1.0,
    ])
    @axesBuffer.itemSize = 3
    @axesBuffer.numItems = vertices.length / @axesBuffer.itemSize
    
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @axesBuffer)
    @gl.bufferData(@gl.ARRAY_BUFFER, vertices, @gl.STATIC_DRAW)
    @gl.vertexAttribPointer(@programs.axes.aVertexPosition1, @axesBuffer.itemSize, @gl.FLOAT, false, 0, 0)
  
  drawAxes3d: ->
    @gl.useProgram(@programs.axes)
    
    mat4.identity(@mvMatrix)
    mat4.translate(@mvMatrix, @mvMatrix, @translateBy)
    mat4.multiply(@mvMatrix, @mvMatrix, @rotationMatrix)
    @_setMatrices(@programs.axes)
    
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @axesBuffer)
    @gl.vertexAttribPointer(@programs.axes.aVertexPosition1, @axesBuffer.itemSize, @gl.FLOAT, false, 0, 0)
    
    @gl.drawArrays(@gl.TRIANGLES, 0, @axesBuffer.numItems)
  
  drawAxes: ->
    # Clear the axes canvas
    @axesCanvas.width = @axesCanvas.width
    
    # TODO: Check FPS, might be worth caching context and creating a setup function
    context = @axesCanvas.getContext('2d')
    context.imageSmoothingEnabled = false
    context.lineWidth = 1
    context.font = "#{@fontSize}px #{@fontFamily}"
    
    context.translate(@xOffset, @yOffset)
    
    lineWidth = context.lineWidth
    
    # Convert canvas pixel units to clipspace units
    lineWidthX = lineWidth * 2 / @width
    lineWidthY = lineWidth * 2 / @height
    
    margin = @getMargin()
    
    # Determine axes given margin and line width
    vertices = new Float32Array([
      # y axis
      -1.0 + margin - lineWidthX, 1.0,
      -1.0 + margin - lineWidthX, -1.0,
      
      # x axis
      -1.0, -1.0 + margin - lineWidthY,
      1.0, -1.0 + margin - lineWidthY
    ])
    
    # Transform to canvas coordinates
    for value, i in vertices by 2
      xp = vertices[i]
      yp = vertices[i + 1]
      
      [x, y] = @xpyp2xy(xp, yp)
      vertices[i] = x
      vertices[i + 1] = y
      
    context.beginPath()
    context.moveTo(vertices[0], vertices[1])
    context.lineTo(vertices[2], vertices[3])
    context.closePath()
    context.stroke()
    
    context.beginPath()
    context.moveTo(vertices[4], vertices[5])
    context.lineTo(vertices[6], vertices[7])
    context.closePath()
    context.stroke()
    
    # Tick marks and numbers
    [x1, y1] = @xpyp2xy(-1.0 + margin, -1.0 + margin)
    [x2, y2] = @xpyp2xy(1.0 - margin, 1.0 - margin)
    xTicks = @linspace(x1, x2, @xTicks + 1).subarray(1)
    yTicks = @linspace(y1, y2, @yTicks + 1).subarray(1)
    
    if @extents?
      context.font = "#{@tickFontSize}px #{@fontFamily}"
      xTickValues = @linspace(@extents.xmin, @extents.xmax, @xTicks + 1).subarray(1)
      yTickValues = @linspace(@extents.ymin, @extents.ymax, @yTicks + 1).subarray(1)
    
    for xTick, index in xTicks
      context.beginPath()
      context.moveTo(xTick, y1)
      context.lineTo(xTick, y1 - @xTickSize)
      context.stroke()
      
      if xTickValues?
        value = xTickValues[index].toFixed(@tickDecimals)
        textWidth = context.measureText(value).width
        
        # NOTE: The 1 should really be line width
        context.fillText("#{value}", xTick - textWidth + 1, y1 + @fontSize + 2)
      
    for yTick, index in yTicks
      context.beginPath()
      context.moveTo(x1 - 1, yTick)
      context.lineTo(x1 - 1 + @yTickSize, yTick)
      context.stroke()
      
      if yTickValues?
        value = yTickValues[index].toFixed(@tickDecimals)
        textWidth = context.measureText(value).width
        
        context.save()
        context.rotate(-Math.PI / 2)
        
        # NOTE: The 1 should really be line width
        context.fillText("#{value}", -1 * (yTick + textWidth - 1), x1 - @fontSize)
        context.restore()
    
    context.font = "#{@fontSize}px #{@fontFamily}"
    key1width = context.measureText(@key1).width
    key2width = context.measureText(@key2).width
    
    # Measurements for x axis
    [x, y] = @xpyp2xy(1.0 - margin, -1.0 + margin)
    x -= key1width
    y += 2 * @fontSize + 8
    context.fillText("#{@key1}", x, y)
    
    # Measurements for y axis
    context.save()
    context.rotate(-Math.PI / 2)
    x = -1 * (margin * @height / 2 + key2width)
    y = margin * @width / 2 - 2 * @fontSize - 8
    context.fillText("#{@key2}", x, y)
    context.restore()
    
  getMargin: ->
    # NOTE: 2 * fontSize incorporates both tick values and axes labels
    # TODO: Better way to do accomplish this by computing margin for
    #       when tick values and axes labels are requested.
    return @margin + (2 * @fontSize + @axisPadding) * 2 / @height
  
  #
  # Transformation functions
  #
  
  # Denoting primed coordinates as clip space (e.g. xp and yp)
  
  # Pixel units to clip space units
  x2xp: (x) -> return 2 / @width * x
  y2yp: (y) -> return -2 / @height * y
  
  # Clip space units to pixel units
  xp2x: (xp) -> return xp * @width / 2
  yp2y: (yp) -> return yp * @height / 2
  
  # Pixel coordinates to clip space coordinates
  xy2xpyp: (x, y) ->
    xp = 2 / @width * x - 1
    yp = -2 / @height * y + 1
    return [xp, yp]
  
  # Clip space coordinates to pixel coordinates
  xpyp2xy: (xp, yp) ->
    x = @width / 2 * (xp + 1)
    y = -@height / 2 * (yp - 1)
    return [x, y]
  
  # Helper methods to check type
  isArray: (obj) ->
    type = Object.prototype.toString.call(obj)
    return if type.indexOf('Array') > -1 then true else false
    
  isObject: (obj) ->
    type = Object.prototype.toString.call(obj)
    return if type.indexOf('Object') > -1 then true else false
  
  # Divide range into equal intervals
  linspace: (start, stop, num) ->
    range = stop - start
    step = range / (num - 1)
    
    steps = new Float32Array(num)
    while num--
      steps[num] = start + num * step
      
    return steps
  
  getExtentFromObjects: (data) ->
    
    keys = Object.keys(data[0])
    i = data.length
    minimums = []
    maximums = []
    
    for key in keys
      minimums.push data[i - 1][key]
      maximums.push data[i - 1][key]
    
    while i--
      for key, index in keys
        val = data[i][key]
        minimums[index] = val if val < minimums[index]
        maximums[index] = val if val > maximums[index]
    return [minimums, maximums]
  
  # Compute the minimum and maximum value of an array with support for NaN values.
  getExtent: (arr) ->
    
    # Set initial values for min and max
    index = arr.length
    while index--
      value = arr[index]
      continue if isNaN(value)
      
      min = max = value
      break
    
    if index is -1
      return [NaN, NaN]
    
    # Continue loop to find extent
    while index--
      value = arr[index]
      
      if isNaN(value)
        continue
        
      if value < min
        min = value
        
      if value > max
        max = value
        
    return [min, max]
  
  # Generic call to plot data
  # this function determines the dimensionality of the
  # data and calls the appropriate function.
  plot: (args...) ->
    
    if args.length is 1
      arg = args[0]
      
      # Check type of argument
      if @isArray(arg)
        
        # Check first element
        datum = arg[0]
        if @isObject(datum)
          
          # Check dimensionality
          keys = Object.keys(datum)
          dimensions = keys.length
          
          switch dimensions
            when 1
              @histogram(arg)
              return
            when 2
              @scatter2D(arg)
              return
            when 3
              @scatter3D(arg)
              return
        else
          # Assuming an array of values
          @histogram(arg)
          return
          
    # Length of arguments is greater than one
    # assume one numerical array per dimension
    
    switch args.length
      when 2
        @scatter2D(args...)
        return
      when 3
        @scatter3D(args...)
        return
        
    # If code gets here, then something wrong with input data
    throw "Input data not recognized by Ruse."
  
  # TODO: Logic on axes drawing can be better.
  animate: ->
    clearInterval(@intervalId) if @isAnimating
    
    i = 0
    @isAnimating = true
    @intervalId = setInterval( =>
      i += 1
      uTime = if @switch is 1 then i / 45 else 1 - i / 45
      @gl.useProgram(@programs.ruse)
      @gl.uniform1f(@uTime, uTime)
      @draw()
      @drawAxes3d() if @state is "scatter3D"
      if i is 45
        clearInterval(@intervalId)
        @isAnimating = false
    , 1000 / 60)


@astro = {} unless @astro?
@astro.Ruse = Ruse
@astro.Ruse.version = '0.1.0'