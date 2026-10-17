-- Brand.spec is injected from branding/logo.json by the package builder.
-- Native frames draw the same mark without a network image dependency.
local Brand={}
function Brand.draw(parent,x,y,size)
 local spec=Brand.spec
 local function color(name)return Color3.fromHex(spec[name])end
 local scale=size/spec.size
 local frame=Instance.new("Frame");frame.Name="KeynovaLogo";frame.Position=UDim2.fromOffset(x,y);frame.Size=UDim2.fromOffset(size,size);frame.BackgroundColor3=color("background");frame.BorderSizePixel=0;frame.Parent=parent
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,spec.radius*scale);corner.Parent=frame
 local border=Instance.new("UIStroke");border.Color=color("border");border.Thickness=1;border.Parent=frame
 local function bar(a,b,width,tint)
  local first,last=Vector2.new(a[1],a[2]),Vector2.new(b[1],b[2]);local delta=last-first
  local line=Instance.new("Frame");line.Name="Stroke";line.AnchorPoint=Vector2.new(0.5,0.5);line.Position=UDim2.fromOffset((first.X+last.X)/2*scale,(first.Y+last.Y)/2*scale);line.Size=UDim2.fromOffset(delta.Magnitude*scale,width*scale);line.Rotation=math.deg(math.atan2(delta.Y,delta.X));line.BackgroundColor3=color(tint);line.BorderSizePixel=0;line.Parent=frame
  local rounding=Instance.new("UICorner");rounding.CornerRadius=UDim.new(1,0);rounding.Parent=line
  -- Rounded endcaps keep native and exported stroke silhouettes aligned.
  for _,point in ipairs({first,last})do local cap=Instance.new("Frame");cap.Name="Cap";cap.AnchorPoint=Vector2.new(0.5,0.5);cap.Position=UDim2.fromOffset(point.X*scale,point.Y*scale);cap.Size=UDim2.fromOffset(width*scale,width*scale);cap.BackgroundColor3=color(tint);cap.BorderSizePixel=0;cap.Parent=frame;local circle=Instance.new("UICorner");circle.CornerRadius=UDim.new(1,0);circle.Parent=cap end
 end
 for _,stroke in ipairs(spec.strokes)do bar(stroke.from,stroke.to,spec.strokeWidth,stroke.color)end
 local d=spec.diamond;local diamond=Instance.new("Frame");diamond.Name="Keyframe";diamond.AnchorPoint=Vector2.new(0.5,0.5);diamond.Position=UDim2.fromOffset(d.center[1]*scale,d.center[2]*scale);diamond.Size=UDim2.fromOffset(d.radius*math.sqrt(2)*scale,d.radius*math.sqrt(2)*scale);diamond.Rotation=45;diamond.BackgroundColor3=color(d.color);diamond.BorderSizePixel=0;diamond.Parent=frame
 return frame
end
return Brand
