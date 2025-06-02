export type Fill = { above: boolean, below: boolean }

export type Region = { vector }

export type Segment = {
	start: vector,
	finish: vector,

	my_fill: Fill,
	other_fill: Fill?,
}

export type Polygon = { regions: { Region }, inverted: boolean }

export type CombinedSegments = { combined: { Segment }, inverted1: boolean, inverted2: boolean }
export type Segments = { segments: { Segment }, inverted: boolean }

return {}
