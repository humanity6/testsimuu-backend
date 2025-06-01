import os
import json
import sys
from django.core.management.base import BaseCommand
from django.urls import get_resolver
from django.contrib.auth import get_user_model
from drf_spectacular.generators import SchemaGenerator
from drf_spectacular.renderers import OpenApiJsonRenderer


class Command(BaseCommand):
    help = 'Generate static API documentation files'

    def add_arguments(self, parser):
        parser.add_argument(
            '--format',
            choices=['json', 'yaml'],
            default='json',
            help='Output format for the schema file'
        )
        parser.add_argument(
            '--path',
            default='api_docs',
            help='Path where to save the generated documentation'
        )
        parser.add_argument(
            '--admin',
            action='store_true',
            help='Include admin endpoints in the documentation'
        )
        parser.add_argument(
            '--separate-admin',
            action='store_true',
            help='Create separate admin documentation folder (default: include admin endpoints in main docs)'
        )

    def handle(self, *args, **options):
        output_format = options['format']
        output_path = options['path']
        include_admin = options.get('admin', False)
        separate_admin = options.get('separate_admin', False)
        
        # Create directory if it doesn't exist
        if not os.path.exists(output_path):
            os.makedirs(output_path)
            self.stdout.write(self.style.SUCCESS(f"Created directory: {output_path}"))
        
        # Temporarily patch IsAdminUser permission check to bypass permission checks for documentation
        if include_admin:
            self._patch_permissions()
            self.stdout.write(self.style.SUCCESS("Temporarily bypassing admin permission checks for documentation generation"))
        
        # Generate schema
        generator = SchemaGenerator()
        schema = generator.get_schema()
        
        # Save schema to file
        if output_format == 'json':
            renderer = OpenApiJsonRenderer()
            schema_content = renderer.render(schema, renderer_context={})
            file_path = os.path.join(output_path, 'schema.json')
            with open(file_path, 'wb') as f:
                f.write(schema_content)
        else:  # yaml
            # Import here to avoid unnecessary dependency if not used
            from drf_spectacular.renderers import OpenApiYamlRenderer
            renderer = OpenApiYamlRenderer()
            schema_content = renderer.render(schema, renderer_context={})
            file_path = os.path.join(output_path, 'schema.yaml')
            with open(file_path, 'wb') as f:
                f.write(schema_content)
        
        # Generate endpoints summary, including admin endpoints if requested
        endpoints = self._get_api_endpoints()
        
        if not include_admin:
            # Filter out admin endpoints if not included
            endpoints = [endpoint for endpoint in endpoints if not endpoint.get('is_admin', False)]
        
        endpoints_file = os.path.join(output_path, 'endpoints.json')
        with open(endpoints_file, 'w') as f:
            json.dump(endpoints, f, indent=2)
        
        # Create index.html with ReDoc
        self._create_redoc_html(output_path, schema_file=os.path.basename(file_path))
        
        # Generate separate admin documentation if requested
        if include_admin and separate_admin:
            self._create_admin_docs(output_path, schema, output_format)
        
        self.stdout.write(self.style.SUCCESS(
            f"API documentation generated successfully at {output_path}"
        ))
    
    def _patch_permissions(self):
        """
        Temporarily patch permission classes to bypass authentication for schema generation
        """
        # Patch users/admin_views.py IsAdminUser permission
        from users.admin_views import IsAdminUser
        
        # Save original has_permission method
        original_has_permission = IsAdminUser.has_permission
        
        # Create a patched method that always returns True
        def patched_has_permission(self, request, view):
            return True
        
        # Apply the patch
        IsAdminUser.has_permission = patched_has_permission
        
        # Also patch any other similar classes in other apps
        # This is a simplistic approach - you might need to add more for other admin views
        try:
            from questions.admin_views import IsAdminUser as QuestionsIsAdminUser
            QuestionsIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        try:
            from exams.admin_views import IsAdminUser as ExamsIsAdminUser
            ExamsIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        try:
            from subscriptions.admin_views import IsAdminUser as SubscriptionsIsAdminUser
            SubscriptionsIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        try:
            from ai_integration.admin_views import IsAdminUser as AIIsAdminUser
            AIIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        try:
            from affiliates.admin_views import IsAdminUser as AffiliatesIsAdminUser
            AffiliatesIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        try:
            from support.admin_views import IsAdminUser as SupportIsAdminUser
            SupportIsAdminUser.has_permission = patched_has_permission
        except ImportError:
            pass
        
        # Also patch the rest_framework.permissions.IsAdminUser
        from rest_framework.permissions import IsAdminUser as DRFIsAdminUser
        DRFIsAdminUser.has_permission = patched_has_permission
    
    def _get_api_endpoints(self):
        """Extract a list of all API endpoints from the URL patterns."""
        from django.urls import URLPattern, URLResolver
        
        def extract_endpoints(patterns, prefix=''):
            endpoints = []
            
            for pattern in patterns:
                if isinstance(pattern, URLPattern):
                    if hasattr(pattern.callback, 'cls') and hasattr(pattern.callback.cls, 'get_serializer'):
                        view_class = pattern.callback.cls
                        view_name = view_class.__name__
                        
                        # Determine HTTP methods
                        http_methods = []
                        for method in ['get', 'post', 'put', 'patch', 'delete']:
                            if hasattr(view_class, method):
                                http_methods.append(method.upper())
                        
                        # Determine if this is an admin endpoint
                        is_admin = 'admin' in prefix.lower()
                        
                        endpoints.append({
                            'path': prefix + str(pattern.pattern),
                            'name': pattern.name or '',
                            'view': view_name,
                            'methods': http_methods,
                            'is_admin': is_admin
                        })
                
                elif isinstance(pattern, URLResolver):
                    extracted = extract_endpoints(
                        pattern.url_patterns, 
                        prefix + str(pattern.pattern)
                    )
                    endpoints.extend(extracted)
            
            return endpoints
        
        resolver = get_resolver()
        return extract_endpoints(resolver.url_patterns)
    
    def _create_redoc_html(self, output_path, schema_file):
        """Create an HTML file with ReDoc for viewing the API docs."""
        html_content = f"""<!DOCTYPE html>
<html>
  <head>
    <title>Testimus API Documentation</title>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
    <style>
      body {{
        margin: 0;
        padding: 0;
      }}
    </style>
  </head>
  <body>
    <redoc spec-url="{schema_file}"></redoc>
    <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"> </script>
  </body>
</html>"""
        
        with open(os.path.join(output_path, 'index.html'), 'w') as f:
            f.write(html_content)
    
    def _create_admin_docs(self, output_path, schema, output_format):
        """Create separate documentation for admin endpoints."""
        # Create admin directory
        admin_path = os.path.join(output_path, 'admin')
        if not os.path.exists(admin_path):
            os.makedirs(admin_path)
            
        # Filter schema to only include admin endpoints
        admin_schema = self._filter_admin_endpoints(schema)
        
        # Save admin schema
        if output_format == 'json':
            renderer = OpenApiJsonRenderer()
            schema_content = renderer.render(admin_schema, renderer_context={})
            file_path = os.path.join(admin_path, 'schema.json')
            with open(file_path, 'wb') as f:
                f.write(schema_content)
        else:  # yaml
            from drf_spectacular.renderers import OpenApiYamlRenderer
            renderer = OpenApiYamlRenderer()
            schema_content = renderer.render(admin_schema, renderer_context={})
            file_path = os.path.join(admin_path, 'schema.yaml')
            with open(file_path, 'wb') as f:
                f.write(schema_content)
        
        # Create admin index.html
        self._create_redoc_html(admin_path, schema_file=os.path.basename(file_path))
        
        # Generate admin endpoints summary
        admin_endpoints = [endpoint for endpoint in self._get_api_endpoints() if endpoint.get('is_admin', False)]
        endpoints_file = os.path.join(admin_path, 'endpoints.json')
        with open(endpoints_file, 'w') as f:
            json.dump(admin_endpoints, f, indent=2)
            
        self.stdout.write(self.style.SUCCESS(
            f"Admin API documentation generated at {admin_path}"
        ))
        
    def _filter_admin_endpoints(self, schema):
        """Filter schema to only include admin endpoints."""
        admin_schema = schema.copy()
        admin_paths = {}
        
        for path, path_item in schema.get('paths', {}).items():
            if '/admin/' in path:
                admin_paths[path] = path_item
        
        admin_schema['paths'] = admin_paths
        return admin_schema 