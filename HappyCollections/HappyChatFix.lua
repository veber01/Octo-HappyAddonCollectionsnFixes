local o = ChatFrame1.SetPoint
ChatFrame1.SetPoint = function(self, ...)
  if strfind(tostring(debugstack(2, 1, 0)), "ManageFramePositions") then return end
  o(self, unpack(arg))
end