requires 'perl', '5.014';
requires 'File::pushd';
requires 'Capture::Tiny';
requires 'version';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

