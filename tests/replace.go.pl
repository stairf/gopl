
@options = (
	{ long => 'foo', type => 'string', replace => { x => 'yz', y => 'zz', '' => 'empty' } },
	{ long => 'bar', type => 'int', replace => { x => '255', y => '-1' } },
	{ short => 'e', type => 'enum', values => 'foo,bar,foo-bar', replace => { f => 'foo-bar', b => 'bar' } },
	{ short => 't', type => 'char', replace => { foo => 'f', bar => 'b' }, init => 0x41 },
);
