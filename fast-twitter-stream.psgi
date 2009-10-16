use AnyEvent::Twitter::Stream;
use Plack::Request;
use Plack::Builder;
use Encode;

my $username = $ENV{TWITTER_USERNAME};
my $password = $ENV{TWITTER_PASSWORD};
my $boundary = '|||';
my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);

    warn "This app needs a server that supports psgi.streaming"
        unless $env->{'psgi.streaming'};

    if ( $req->path eq '/push' ) {
        my $cv       = AE::cv;
        my $streamer = AnyEvent::Twitter::Stream->new(
            username => $username,
            password => $password,
            method   => 'filter',
            track    => 'twitter',
            on_tweet => sub { $cv->send(@_) },
        );
        return sub {
            my $respond = shift;
            my $w  = $respond->([
                200,
                [ 'Content-Type' => qq{multipart/mixed; boundary="$boundary"} ]
            ]);
            my $cb;
            $cb = sub {
                my $tweet = shift->recv;
                my $body  = '';
                if ( $tweet->{text} ) {
                    $body =
                        "--$boundary\nContent-Type: text/html\n"
                            . Encode::encode_utf8( $tweet->{text} );
                }
                $w->write($body);
                $cv = AE::cv;
                $cv->cb( $cb );
            };
            $cv->cb( $cb );
        }
    }
    if ( $req->path eq '/' ) {
        my $res = $req->new_response(200);
        $res->content_type('text/html');
        $res->body( html() );
        $res->finalize;
    }
};

builder {
    enable "Plack::Middleware::Static",
        path => qr{\.(?:png|jpg|gif|css|txt|js)$},
            root => './static/';
    $app;
};

sub html {
    my $html = <<'HTML';
<html><head>
<title>Server Push</title>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.3.1/jquery.min.js"></script>
<script type="text/javascript" src="/js/DUI.js"></script>
<script type="text/javascript" src="/js/Stream.js"></script>
<script type="text/javascript">
$(function() {
var s = new DUI.Stream();
s.listen('text/html', function(payload) {
$('#content').prepend('<p>' + payload + '</p>');
});
s.load('/push');
});
</script>
</head>
<body>
<h1>Server Push</h1>
<div id="content"></div>
</body>
</html>
HTML
    return $html;
}
