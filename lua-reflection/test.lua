function HandleEvent( event )
	local running
	running = true
	if event.id == 0x202 then
		running = false
	end
	print(event["id"])
	
	return running
end

function DrawScreen()
	SetColor2D(255, 0, 0)
	DrawRect2D(0, 0, 32, 32)
	
	SetColor2D(0, 255, 0)
	DrawRect2D(32, 0, 32, 32)
	
	SetColor2D(0, 0, 255)
	DrawRect2D(64, 0, 32, 32)
end
