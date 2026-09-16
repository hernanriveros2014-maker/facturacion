from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(['GET'])
@permission_classes([AllowAny])
def health(request):
    """Endpoint público para verificar que la API responde."""
    return Response({
        'status': 'ok',
        'service': 'facturacion-api',
    })
